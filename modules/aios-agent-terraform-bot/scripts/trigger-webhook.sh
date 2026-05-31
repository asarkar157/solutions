#!/usr/bin/env bash
# Trigger terraform-module-update via Guild webhook (local dev or remote StackGen).
# Usage:
#   ./trigger-webhook.sh --issue 901 --title "Add aws_scheduler_schedule module" --module aws_scheduler_schedule
#   ./trigger-webhook.sh --from-tofu-output   # reads terraform/guild tofu output
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUILD_URL="${GUILD_URL:-http://localhost:8088}"
ORG_ID="${ORG_ID:-74301888-bab0-4af5-a882-2de0a491651f}"
API_KEY="${API_KEY:-}"
ISSUE_NUM=""
ISSUE_TITLE=""
ISSUE_BODY=""
REPO="stackgenhq/discovery-modules"
FROM_TOFU=0

usage() {
  cat <<EOF
Usage: $0 [--guild-url URL] [--org-id UUID] [--api-key TOKEN] [--issue N] [--title TEXT] [--body TEXT] [--from-tofu-output]

Triggers POST /api/v1/webhooks/trigger for terraform-bot-github-receiver → terraform-module-update.
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --guild-url) GUILD_URL="$2"; shift 2 ;;
    --org-id) ORG_ID="$2"; shift 2 ;;
    --api-key) API_KEY="$2"; shift 2 ;;
    --issue) ISSUE_NUM="$2"; shift 2 ;;
    --title) ISSUE_TITLE="$2"; shift 2 ;;
    --body) ISSUE_BODY="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --from-tofu-output) FROM_TOFU=1; shift ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

if [ "$FROM_TOFU" -eq 1 ]; then
  TF_DIR="${TF_DIR:-$ROOT/../../../stackgen-guild/terraform/guild}"
  if [ ! -d "$TF_DIR" ]; then
    echo "error: TF_DIR not found: $TF_DIR" >&2
    exit 1
  fi
  blob="$(cd "$TF_DIR" && tofu output -json terraform_bot_webhook 2>/dev/null || terraform output -json terraform_bot_webhook 2>/dev/null || true)"
  if [ -z "$blob" ]; then
    echo "error: terraform_bot_webhook output missing — apply terraform/guild first" >&2
    exit 1
  fi
  API_KEY="$(printf '%s' "$blob" | jq -r '.token // empty')"
  ingress="$(printf '%s' "$blob" | jq -r '.ingress_payload_url // empty')"
  if [ -n "$ingress" ] && [ "$ingress" != "null" ]; then
    TRIGGER_URL="$ingress"
  fi
fi

if [ -z "${TRIGGER_URL:-}" ]; then
  if [ -z "$API_KEY" ]; then
    echo "error: set --api-key or --from-tofu-output" >&2
    exit 1
  fi
  TRIGGER_URL="${GUILD_URL%/}/api/v1/webhooks/trigger?apiKey=${API_KEY}&orgId=${ORG_ID}"
fi

if [ -z "$ISSUE_NUM" ]; then
  ISSUE_NUM="$(date +%s | tail -c 6)"
fi
if [ -z "$ISSUE_TITLE" ]; then
  ISSUE_TITLE="discovery-module-request test issue ${ISSUE_NUM}"
fi
if [ -z "$ISSUE_BODY" ]; then
  ISSUE_BODY="Automated terraform-bot webhook test for issue ${ISSUE_NUM}."
fi

owner="${REPO%%/*}"
name="${REPO#*/}"

payload="$(jq -n \
  --arg action "opened" \
  --argjson number "$ISSUE_NUM" \
  --arg title "$ISSUE_TITLE" \
  --arg body "$ISSUE_BODY" \
  --arg repo "$REPO" \
  --arg owner "$owner" \
  --arg name "$name" \
  '{
    action: $action,
    issue: {
      number: $number,
      title: $title,
      body: $body,
      state: "open",
      user: { login: "terraform-bot-tester" },
      labels: [
        { name: "discovery-module-request" }
      ]
    },
    repository: {
      full_name: $repo,
      name: $name,
      owner: { login: $owner },
      clone_url: ("https://github.com/" + $repo + ".git"),
      default_branch: "main"
    }
  }')"

echo "POST $TRIGGER_URL"
resp="$(curl -sS -X POST "$TRIGGER_URL" \
  -H "Content-Type: application/json" \
  -d "$payload")"
echo "$resp" | jq . 2>/dev/null || echo "$resp"

run_id="$(printf '%s' "$resp" | jq -r '.run_id // .workflow_run_id // .id // empty' 2>/dev/null || true)"
if [ -n "$run_id" ] && [ "$run_id" != "null" ]; then
  echo "run_id=$run_id"
fi
