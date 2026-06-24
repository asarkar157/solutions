#!/usr/bin/env bash
# Trigger cdk-app-update via GitHub-style webhook payload (localhost:8088 dev-edge).
set -euo pipefail

SCENARIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRIGGER_URL=""
ISSUE_NUM=""
ISSUE_TITLE=""
ISSUE_BODY=""
REPO="sks/cdk-typescript-demo"
FROM_TOFU=0
CREATE_GITHUB_ISSUE=0

pick_tf() {
  command -v tofu >/dev/null 2>&1 && echo tofu || echo terraform
}

usage() {
  cat <<'EOF'
Usage: trigger-webhook.sh [options]

  --from-tofu-output       Read webhook_ingress_payload_url from scenario tofu output
  --repo OWNER/NAME        Target GitHub repository (default: sks/cdk-typescript-demo)
  --issue N                Issue number in payload
  --title TEXT             Issue title
  --body TEXT              Issue body
  --create-github-issue    Open issue via gh before triggering
  -h|--help
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
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
  tf="$(pick_tf)"
  TRIGGER_URL="$(
    cd "$SCENARIO_DIR" && "$tf" output -raw webhook_ingress_payload_url 2>/dev/null || true
  )"
  if [ -z "$TRIGGER_URL" ] || [ "$TRIGGER_URL" = "null" ]; then
    echo "error: webhook_ingress_payload_url empty — run tofu apply in ${SCENARIO_DIR}" >&2
    exit 1
  fi
fi

if [ -z "${TRIGGER_URL:-}" ]; then
  echo "error: set --from-tofu-output" >&2
  exit 1
fi

if [ -z "$ISSUE_TITLE" ]; then
  ISSUE_TITLE="Fix encryption on SampleStack $(date +%H%M%S)"
fi
if [ -z "$ISSUE_BODY" ]; then
  ISSUE_BODY="Enable KMS encryption on the S3 bucket in lib/sample-stack.ts. cdk-bot bring-up test $(date +%Y%m%d-%H%M%S)."
fi

if [ "$CREATE_GITHUB_ISSUE" -eq 1 ]; then
  command -v gh >/dev/null 2>&1 || { echo "error: gh required for --create-github-issue" >&2; exit 1; }
  issue_url="$(gh issue create --repo "$REPO" --title "$ISSUE_TITLE" --body "$ISSUE_BODY" 2>/dev/null || true)"
  if [ -z "$issue_url" ]; then
    echo "error: gh issue create failed for $REPO" >&2
    exit 1
  fi
  ISSUE_NUM="${issue_url##*/}"
  echo "github_issue=$issue_url"
fi

if [ -z "$ISSUE_NUM" ]; then
  ISSUE_NUM="$(date +%s | tail -c 6)"
  echo "warn: no real GitHub issue — progress comments may skip" >&2
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
      labels: []
    },
    repository: {
      full_name: $repo,
      name: $name,
      owner: { login: $owner },
      clone_url: ("https://github.com/" + $repo + ".git"),
      default_branch: "main"
    }
  }')"

echo "POST ${TRIGGER_URL%%\?*}?…"
resp="$(curl -sS -X POST "$TRIGGER_URL" -H "Content-Type: application/json" -d "$payload")"
echo "$resp" | jq . 2>/dev/null || echo "$resp"

run_id="$(printf '%s' "$resp" | jq -r '.run_id // .workflow_run_id // .id // empty' 2>/dev/null || true)"
[ -n "$run_id" ] && [ "$run_id" != "null" ] && echo "run_id=$run_id"
