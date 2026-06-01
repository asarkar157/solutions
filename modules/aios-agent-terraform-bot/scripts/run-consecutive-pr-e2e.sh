#!/usr/bin/env bash
# Run N sequential terraform-bot webhook triggers; exit when N PRs created or on hard failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT/scripts"
TARGET_PRs="${1:-4}"
GUILD_URL="${GUILD_URL:-http://localhost:8081}"
ORG_ID="${ORG_ID:-74301888-bab0-4af5-a882-2de0a491651f}"
TIMEOUT="${WORKFLOW_TIMEOUT:-3600}"

cases=(
  "Add aws_scheduler_schedule discovery module|EventBridge Scheduler schedule resource"
  "Add aws_verifiedaccess_trust_provider module|AWS Verified Access trust provider"
  "Add aws_ecs_service_blue_green module|ECS blue/green deployment service module"
  "Add aws_cloudwatch_event_rule discovery module|CloudWatch Events rule module scaffold"
)

success=0

for entry in "${cases[@]}"; do
  [ "$success" -ge "$TARGET_PRs" ] && break
  IFS='|' read -r title body <<<"$entry"
  echo "=== Trigger $((success + 1))/$TARGET_PRs: $title ==="
  resp="$("$SCRIPTS/trigger-webhook.sh" --from-tofu-output --create-github-issue --title "$title" --body "$body" 2>&1)"
  printf '%s\n' "$resp"
  run_id="$(printf '%s' "$resp" | grep -E '^run_id=' | cut -d= -f2- || true)"
  sleep 20
  trace_id="$(psql "${PG_URL:-postgres://guild:guild@localhost:5433/guild_db?sslmode=disable}" -t -A -c \
    "SELECT trace_id FROM execution_agent_summaries WHERE workflow_name='terraform-module-update' ORDER BY created_at DESC LIMIT 1;" | tr -d '[:space:]')"
  echo "monitor trace_id=$trace_id run_id=$run_id"
  if "$SCRIPTS/monitor-workflow-run.sh" --trace-id "$trace_id" --timeout "$TIMEOUT"; then
    success=$((success + 1))
    echo "=== PR $success/$TARGET_PRs OK ==="
  else
    echo "=== Run failed (trace $trace_id) — stopping ===" >&2
    exit 1
  fi
done

echo "DONE: $success consecutive PR(s) created"
[ "$success" -ge "$TARGET_PRs" ]
