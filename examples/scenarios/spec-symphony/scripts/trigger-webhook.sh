#!/usr/bin/env bash
# Trigger spec-driven-feature via GitHub-style webhook payload.
#
# From repo root:
#   cd examples/scenarios/spec-symphony
#   ./scripts/trigger-webhook.sh --from-tofu-output --repo owner/name --issue 1
#
# Or create a real issue first:
#   ./scripts/trigger-webhook.sh --from-tofu-output --create-github-issue \
#     --repo owner/my-app --title "CORE-101 Add user profile API"
set -euo pipefail

SCENARIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUILD_URL="${GUILD_URL:-}"
ORG_ID="${ORG_ID:-}"
API_KEY="${API_KEY:-}"
TRIGGER_URL="${TRIGGER_URL:-}"
ISSUE_NUM=""
ISSUE_TITLE=""
ISSUE_BODY=""
REPO=""
FROM_TOFU=0
CREATE_GITHUB_ISSUE=0
SDD_FRAMEWORK="auto"
CHANGE_TYPE="brownfield"

pick_tf() {
  command -v tofu >/dev/null 2>&1 && echo tofu || echo terraform
}

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

usage() {
  cat <<'EOF'
Usage: trigger-webhook.sh [options]

  --from-tofu-output       Read github_webhook_trigger_url from scenario tofu output
  --guild-url URL          Override Guild base URL
  --org-id UUID            orgId query param (optional)
  --api-key TOKEN          Webhook apiKey (if not using --from-tofu-output)
  --repo OWNER/NAME        Target GitHub repository
  --issue N                Issue/PR number in payload
  --title TEXT             Issue title
  --body TEXT              Issue body
  --sdd-framework VAL      spec-kit | openspec | auto (workflow optional input)
  --change-type VAL        greenfield | brownfield | ...
  --create-github-issue    Open issue via gh before triggering
  -h|--help
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
    --sdd-framework) SDD_FRAMEWORK="$2"; shift 2 ;;
    --change-type) CHANGE_TYPE="$2"; shift 2 ;;
    --create-github-issue) CREATE_GITHUB_ISSUE=1; shift ;;
    --from-tofu-output) FROM_TOFU=1; shift ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

if [ "$FROM_TOFU" -eq 1 ]; then
  tf="$(pick_tf)"
  TRIGGER_URL="$(
    cd "$SCENARIO_DIR" && "$tf" output -raw github_webhook_trigger_url 2>/dev/null || true
  )"
  if [ -z "$TRIGGER_URL" ] || [ "$TRIGGER_URL" = "null" ]; then
    echo "error: github_webhook_trigger_url empty — run tofu apply in ${SCENARIO_DIR}" >&2
    exit 1
  fi
  if [ -z "$REPO" ]; then
  REPO="$(cd "$SCENARIO_DIR" && "$tf" output -raw target_repository_full_name 2>/dev/null || true)"
  fi
fi

if [ -z "${TRIGGER_URL:-}" ]; then
  if [ -z "$API_KEY" ]; then
    echo "error: set --api-key or --from-tofu-output" >&2
    exit 1
  fi
  if [ -z "$GUILD_URL" ]; then
    echo "error: set --guild-url with --api-key" >&2
    exit 1
  fi
  TRIGGER_URL="${GUILD_URL%/}$(webhook_trigger_path)?apiKey=${API_KEY}"
  [ -n "$ORG_ID" ] && TRIGGER_URL="${TRIGGER_URL}&orgId=${ORG_ID}"
fi

if [ -z "$REPO" ]; then
  echo "error: set --repo OWNER/NAME or target_repository_full_name in terraform.tfvars" >&2
  exit 1
fi

if [ -z "$ISSUE_TITLE" ]; then
  ISSUE_TITLE="CORE-101 Spec-symphony test $(date +%s | tail -c 6)"
fi
if [ -z "$ISSUE_BODY" ]; then
  ISSUE_BODY="Automated spec-symphony webhook test. Implement a small README section documenting SPEC_SYMPHONY.md usage."
fi

if [ "$CREATE_GITHUB_ISSUE" -eq 1 ] || { [ -z "$ISSUE_NUM" ] && command -v gh >/dev/null 2>&1; }; then
  command -v gh >/dev/null 2>&1 || { echo "error: gh required for --create-github-issue" >&2; exit 1; }
  issue_url="$(gh issue create --repo "$REPO" --title "$ISSUE_TITLE" --body "$ISSUE_BODY" \
    --label "spec-symphony" 2>/dev/null || \
    gh issue create --repo "$REPO" --title "$ISSUE_TITLE" --body "$ISSUE_BODY" 2>/dev/null)"
  ISSUE_NUM="${issue_url##*/}"
  echo "github_issue=$issue_url"
fi

if [ -z "$ISSUE_NUM" ]; then
  ISSUE_NUM="$(date +%s | tail -c 6)"
  echo "warn: no real GitHub issue — notify stages may skip (use gh + omit --issue to auto-create)" >&2
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
  --arg sdd "$SDD_FRAMEWORK" \
  --arg ct "$CHANGE_TYPE" \
  '{
    action: $action,
    issue: {
      number: $number,
      title: $title,
      body: $body,
      state: "open",
      user: { login: "spec-symphony-tester" },
      labels: [{ name: "spec-symphony" }]
    },
    repository: {
      full_name: $repo,
      name: $name,
      owner: { login: $owner },
      clone_url: ("https://github.com/" + $repo + ".git"),
      default_branch: "main"
    },
    sdd_framework: $sdd,
    change_type: $ct
  }')"

echo "POST ${TRIGGER_URL%%\?*}?…"
resp="$(curl -sS -X POST "$TRIGGER_URL" -H "Content-Type: application/json" -d "$payload")"
echo "$resp" | jq . 2>/dev/null || echo "$resp"

run_id="$(printf '%s' "$resp" | jq -r '.run_id // .workflow_run_id // .id // empty' 2>/dev/null || true)"
[ -n "$run_id" ] && [ "$run_id" != "null" ] && echo "run_id=$run_id"
