#!/usr/bin/env bash
# Poll Guild Postgres for terraform-module-update workflow completion and PR URL in events.
# Usage: ./monitor-workflow-run.sh [--trace-id ID] [--run-id UUID] [--timeout 900]
set -euo pipefail

PG_URL="${PG_URL:-postgres://guild:guild@localhost:5433/guild_db?sslmode=disable}"
TRACE_ID=""
RUN_ID=""
TIMEOUT=900
POLL=15

while [ $# -gt 0 ]; do
  case "$1" in
    --trace-id) TRACE_ID="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --poll) POLL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--trace-id ID] [--run-id UUID] [--timeout seconds]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

deadline=$(( $(date +%s) + TIMEOUT ))

resolve_trace_from_run_id() {
  local rid="$1"
  psql "$PG_URL" -t -A -c \
    "SELECT trace_id FROM execution_agent_summaries WHERE session_id IN (
       SELECT session_id FROM execution_agent_summaries WHERE trace_id LIKE '%' LIMIT 0
     ) LIMIT 0;" 2>/dev/null || true
  # run_id from webhook often appears in workflow notes / recent traces — pick newest terraform workflow.
  psql "$PG_URL" -t -A -c \
    "SELECT trace_id FROM execution_agent_summaries
     WHERE workflow_name='terraform-module-update'
     ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || true
}

while [ "$(date +%s)" -lt "$deadline" ]; do
  if [ -n "$RUN_ID" ] && [ -z "$TRACE_ID" ]; then
    TRACE_ID="$(resolve_trace_from_run_id "$RUN_ID")"
    TRACE_ID="$(printf '%s' "$TRACE_ID" | tr -d '[:space:]')"
  fi

  if [ -z "$TRACE_ID" ]; then
    echo "waiting for trace_id..."
    sleep "$POLL"
    continue
  fi

  last_stage="$(psql "$PG_URL" -t -A -c \
    "SELECT event_data->'data'->>'Message' FROM execution_events
     WHERE trace_id='$TRACE_ID' AND event_type IN ('RUN_STARTED','RUN_FINISHED')
     ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || true)"
  last_stage="$(printf '%s' "$last_stage" | tr -d '[:space:]')"

  exec_count="$(psql "$PG_URL" -t -A -c \
    "SELECT COUNT(*) FROM execution_events
     WHERE trace_id='$TRACE_ID'
       AND (event_data->'data'->>'ToolName' LIKE '%execute_series'
         OR event_data::text ILIKE '%execute_series%');" 2>/dev/null || true)"

  # Prefer execute_series stdout; fall back to any event on this trace (sub-agent output often lands in note/chunks).
  pr_line="$(psql "$PG_URL" -t -A -c \
    "SELECT event_data::text FROM execution_events
     WHERE trace_id='$TRACE_ID'
       AND event_data::text ~ 'https://github\\.com/[^\"\\\\]+/pull/[0-9]+'
       AND event_data::text ~ '(pr_url=|\"pr_url\"|pull/[0-9]+)'
     ORDER BY seq DESC LIMIT 1;" 2>/dev/null || true)"

  draft_line="$(psql "$PG_URL" -t -A -c \
    "SELECT event_data::text FROM execution_events
     WHERE trace_id='$TRACE_ID'
       AND event_data::text ILIKE '%pr_draft=true%'
       AND (event_data::text ILIKE '%fmt_exit=%' OR event_data::text ILIKE '%module_quality_summary%')
     ORDER BY seq DESC LIMIT 1;" 2>/dev/null || true)"

  summary_status="$(psql "$PG_URL" -t -A -c \
    "SELECT status FROM execution_agent_summaries WHERE trace_id='$TRACE_ID' LIMIT 1;" 2>/dev/null || true)"
  summary_status="$(printf '%s' "$summary_status" | tr -d '[:space:]')"

  echo "[$(date -Iseconds)] trace=$TRACE_ID stage=${last_stage:-?} execute_series_calls=${exec_count:-0} status=${summary_status:-?}"

  pr_url="$(printf '%s' "$pr_line" | grep -oE 'https://github.com/[^\"\\]+/pull/[0-9]+' | head -1 || true)"
  if [ -n "$pr_url" ]; then
    echo "SUCCESS pr_url=$pr_url"
    exit 0
  fi

  if printf '%s' "$draft_line" | grep -q 'pr_draft=true'; then
    echo "SUCCESS pr_draft=true (draft PR marker on trace — URL may follow)"
    exit 0
  fi

  if [ "$summary_status" = "completed" ] || [ "$summary_status" = "failed" ]; then
    branch_line="$(psql "$PG_URL" -t -A -c \
      "SELECT event_data::text FROM execution_events
       WHERE trace_id='$TRACE_ID'
         AND event_data::text ~ 'terraform-bot/'
       ORDER BY seq DESC LIMIT 1;" 2>/dev/null || true)"
    branch_name="$(printf '%s' "$branch_line" | grep -oE 'terraform-bot/[^\"\\]+' | head -1 || true)"
    if [ -n "$branch_name" ] && command -v gh >/dev/null 2>&1; then
      gh_pr="$(gh pr list --repo "${E2E_REPO:-stackgenhq/discovery-modules}" --head "$branch_name" --json url -q '.[0].url' 2>/dev/null || true)"
      if [ -n "$gh_pr" ] && [ "$gh_pr" != "null" ]; then
        echo "SUCCESS pr_url=$gh_pr (resolved via gh after workflow completed)"
        exit 0
      fi
    fi
    blocker="$(psql "$PG_URL" -t -A -c \
      "SELECT event_data::text FROM execution_events WHERE trace_id='$TRACE_ID'
       AND (event_data::text ILIKE '%stage_summary:create-pr%BLOCKED%'
         OR event_data::text ILIKE '%pr_blocker%'
         OR event_data::text ILIKE '%module_quality_summary=BLOCKED%')
       ORDER BY seq DESC LIMIT 1;" 2>/dev/null || true)"
    if [ -n "$blocker" ]; then
      echo "DONE without PR (workflow $summary_status):"
      printf '%s\n' "$blocker" | head -c 800
      exit 2
    fi
    if [ "$summary_status" = "completed" ]; then
      echo "DONE without PR (workflow completed, no execute_series PR markers)"
      exit 2
    fi
  fi

  workflow_done="$(psql "$PG_URL" -t -A -c \
    "SELECT COUNT(*) FROM execution_events
     WHERE trace_id='$TRACE_ID' AND event_type='RUN_FINISHED'
       AND event_data->'data'->>'Message'='done';" 2>/dev/null || true)"

  if [ "${workflow_done:-0}" -gt 0 ] && [ -z "$pr_url" ] && ! printf '%s' "$draft_line" | grep -q 'pr_draft=true'; then
    blocker="$(psql "$PG_URL" -t -A -c \
      "SELECT event_data::text FROM execution_events WHERE trace_id='$TRACE_ID'
       AND (event_data::text ILIKE '%pr_blocker%' OR event_data::text ILIKE '%module_quality_summary=BLOCKED%')
       ORDER BY seq DESC LIMIT 1;" 2>/dev/null || true)"
    echo "DONE without PR:"
    printf '%s\n' "$blocker" | head -c 800
    exit 2
  fi

  sleep "$POLL"
done

echo "TIMEOUT waiting for PR (trace_id=$TRACE_ID)"
exit 3
