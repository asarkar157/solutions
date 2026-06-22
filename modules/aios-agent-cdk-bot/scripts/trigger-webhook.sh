#!/usr/bin/env bash
# Trigger cdk-app-update via Guild webhook (local dev or remote StackGen).
# Usage:
#   GUILD_URL=http://localhost:8081 ./trigger-webhook.sh --from-tofu-output --issue 901 --title "Add aws_scheduler_schedule module"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Local direct Guild API (8081): /api/v1/webhooks/trigger. Public StackGen (ai.dev…): /guild/api/v1/webhooks/trigger.
GUILD_URL="${GUILD_URL:-http://localhost:8081}"

webhook_trigger_path() {
  case "${GUILD_URL}" in
    http://localhost:*|http://127.0.0.1:*|https://localhost:*|https://127.0.0.1:*)
      printf '%s' "/api/v1/webhooks/trigger"
      ;;
    *)
      printf '%s' "/guild/api/v1/webhooks/trigger"
      ;;
  esac
}
ORG_ID="${ORG_ID:-74301888-bab0-4af5-a882-2de0a491651f}"
API_KEY="${API_KEY:-}"
ISSUE_NUM=""
ISSUE_TITLE=""
ISSUE_BODY=""
REPO="stackgenhq/discovery-modules"
FROM_TOFU=0
CREATE_GITHUB_ISSUE=0

usage() {
  cat <<EOF
Usage: $0 [--guild-url URL] [--org-id UUID] [--api-key TOKEN] [--issue N] [--title TEXT] [--body TEXT] [--repo OWNER/NAME] [--create-github-issue] [--from-tofu-output]

Triggers POST …/webhooks/trigger for cdk-bot-github-receiver → cdk-app-update.
Local dev: GUILD_URL=http://localhost:8081 → /api/v1/webhooks/trigger.
Remote: https://ai.dev.stackgen.com → /guild/api/v1/webhooks/trigger.

When --create-github-issue is set, opens a real GitHub issue (with discovery-module-request label)
and uses its number in the webhook payload so create-pr issue comments succeed.
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
    --create-github-issue) CREATE_GITHUB_ISSUE=1; shift ;;
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
    # Prefer explicit GUILD_URL; rewrite common local ingress port to direct API.
    if [ "$GUILD_URL" = "http://localhost:8081" ] && printf '%s' "$ingress" | grep -q ':8088'; then
      TRIGGER_URL="$(printf '%s' "$ingress" | sed 's|:8088|:8081|')"
    elif [ -n "${GUILD_URL:-}" ]; then
      TRIGGER_URL="${GUILD_URL%/}$(webhook_trigger_path)?apiKey=${API_KEY}&orgId=${ORG_ID}"
    else
      TRIGGER_URL="$ingress"
    fi
  fi
fi

if [ -z "${TRIGGER_URL:-}" ]; then
  if [ -z "$API_KEY" ]; then
    echo "error: set --api-key or --from-tofu-output" >&2
    exit 1
  fi
  TRIGGER_URL="${GUILD_URL%/}$(webhook_trigger_path)?apiKey=${API_KEY}&orgId=${ORG_ID}"
fi

if [ -z "$ISSUE_TITLE" ]; then
  ISSUE_TITLE="discovery-module-request test issue $(date +%s | tail -c 6)"
fi
if [ -z "$ISSUE_BODY" ]; then
  ISSUE_BODY="Automated cdk-bot webhook test."
fi

if [ "$CREATE_GITHUB_ISSUE" -eq 1 ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI required for --create-github-issue" >&2
    exit 1
  fi
  issue_url="$(gh issue create --repo "$REPO" --title "$ISSUE_TITLE" --body "$ISSUE_BODY" \
    --label "discovery-module-request" 2>/dev/null || \
    gh issue create --repo "$REPO" --title "$ISSUE_TITLE" --body "$ISSUE_BODY" 2>/dev/null)"
  ISSUE_NUM="${issue_url##*/}"
  echo "github_issue=$issue_url"
fi

if [ -z "$ISSUE_NUM" ]; then
  ISSUE_NUM="$(date +%s | tail -c 6)"
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
      user: { login: "cdk-bot-tester" },
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
