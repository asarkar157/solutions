#!/usr/bin/env bash
# Poll Guild Postgres for terraform-module-update workflow completion and PR URL in events.
# Usage: ./monitor-workflow-run.sh [--trace-id ID] [--session-id ID] [--timeout 900]
set -euo pipefail

PG_URL="${PG_URL:-postgres://guild:guild@localhost:5433/guild_db?sslmode=disable}"
TRACE_ID=""
SESSION_ID=""
TIMEOUT=900
POLL=15

while [ $# -gt 0 ]; do
  case "$1" in
    --trace-id) TRACE_ID="$2"; shift 2 ;;
    --session-id) SESSION_ID="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --poll) POLL="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--trace-id ID] [--session-id ID] [--timeout seconds]"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

deadline=$(( $(date +%s) + TIMEOUT ))

while [ "$(date +%s)" -lt "$deadline" ]; do
  if [ -n "$SESSION_ID" ] && [ -z "$TRACE_ID" ]; then
    TRACE_ID="$(psql "$PG_URL" -t -A -c \
      "SELECT trace_id FROM execution_agent_summaries WHERE session_id='$SESSION_ID' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || true)"
    TRACE_ID="$(printf '%s' "$TRACE_ID" | tr -d '[:space:]')"
  fi

  if [ -z "$TRACE_ID" ]; then
    echo "waiting for trace_id..."
    sleep "$POLL"
    continue
  fi

  status_line="$(psql "$PG_URL" -t -A -c \
    "SELECT agent_name||':'||status FROM execution_agent_summaries WHERE trace_id='$TRACE_ID' AND agent_name='terraform-module-manager' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || true)"
  pr_line="$(psql "$PG_URL" -t -A -c \
    "SELECT event_data::text FROM execution_events WHERE trace_id='$TRACE_ID' AND event_data::text ILIKE '%pr_url=%' ORDER BY seq DESC LIMIT 1;" 2>/dev/null || true)"

  echo "[$(date -Iseconds)] trace=$TRACE_ID manager=$status_line"

  if printf '%s' "$pr_line" | grep -q 'pr_url='; then
    pr_url="$(printf '%s' "$pr_line" | grep -oE 'https://github.com/[^\"\\]+/pull/[0-9]+' | head -1 || true)"
    if [ -n "$pr_url" ]; then
      echo "SUCCESS pr_url=$pr_url"
      exit 0
    fi
  fi

  cron_done="$(psql "$PG_URL" -t -A -c \
    "SELECT status FROM execution_agent_summaries WHERE trace_id='$TRACE_ID' AND agent_name='cron-scheduler' LIMIT 1;" 2>/dev/null || true)"
  cron_done="$(printf '%s' "$cron_done" | tr -d '[:space:]')"
  has_manager="$(psql "$PG_URL" -t -A -c \
    "SELECT COUNT(*) FROM execution_agent_summaries WHERE trace_id='$TRACE_ID' AND agent_name='terraform-module-manager';" 2>/dev/null || true)"

  if [ "$cron_done" = "completed" ] && [ "${has_manager:-0}" -gt 0 ]; then
    manager_status="$(psql "$PG_URL" -t -A -c \
      "SELECT status FROM execution_agent_summaries WHERE trace_id='$TRACE_ID' AND agent_name='terraform-module-manager' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null || true)"
    manager_status="$(printf '%s' "$manager_status" | tr -d '[:space:]')"
    if [ "$manager_status" = "completed" ] && ! printf '%s' "$pr_line" | grep -q 'pr_url='; then
      blocker="$(psql "$PG_URL" -t -A -c \
        "SELECT event_data::text FROM execution_events WHERE trace_id='$TRACE_ID' AND event_data::text ILIKE '%pr_blocker%' ORDER BY seq DESC LIMIT 1;" 2>/dev/null || true)"
      echo "DONE without PR (check blockers):"
      printf '%s\n' "$blocker" | head -c 500
      exit 2
    fi
  fi

  sleep "$POLL"
done

echo "TIMEOUT waiting for PR (trace_id=$TRACE_ID)"
exit 3
