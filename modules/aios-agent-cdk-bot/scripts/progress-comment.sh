#!/usr/bin/env bash
# POST or PATCH the live cdk-bot workflow progress table on a GitHub issue.
# Invoked via spawn-context one-liner (env prefix on subprocess) or positional args:
#   progress-comment.sh REPO_FULL_NAME ISSUE_OR_PR [PROGRESS_COMMENT_ID]
set -euo pipefail

REPO_FULL_NAME="${1:-${REPO_FULL_NAME:?set REPO_FULL_NAME before progress comment}}"
ISSUE_OR_PR="${2:-${ISSUE_OR_PR:?set ISSUE_OR_PR before progress comment}}"
COMMENT_ID="${3:-${PROGRESS_COMMENT_ID:-}}"
MODULE_PREFIX="${CDKBOT_MODULE_PREFIX:-cdk-bot}"

progress_icon() {
  case "${1:-pending}" in
    done) printf '✅' ;;
    running) printf '⏳' ;;
    blocked | failed) printf '❌' ;;
    skipped) printf '⏭️' ;;
    *) printf '⬜' ;;
  esac
}

progress_label() {
  case "${1:-pending}" in
    done | running | blocked | failed | skipped | pending) printf '%s' "$1" ;;
    *) printf 'pending' ;;
  esac
}

MARK_INTAKE="${PROGRESS_intake:-pending}"
MARK_IMPLEMENT="${PROGRESS_implement:-pending}"
MARK_VALIDATE="${PROGRESS_validate:-pending}"
MARK_PR="${PROGRESS_pr:-pending}"
DETAIL="${PROGRESS_DETAIL:-}"

BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

{
  printf '%s\n\n' "### ${MODULE_PREFIX} workflow progress"
  printf '%s\n' "| Step | Status |"
  printf '%s\n' "|------|--------|"
  printf '| Intake & clone | %s %s |\n' "$(progress_icon "$MARK_INTAKE")" "$(progress_label "$MARK_INTAKE")"
  printf '| Implement CDK | %s %s |\n' "$(progress_icon "$MARK_IMPLEMENT")" "$(progress_label "$MARK_IMPLEMENT")"
  printf '| Validate & test | %s %s |\n' "$(progress_icon "$MARK_VALIDATE")" "$(progress_label "$MARK_VALIDATE")"
  printf '| PR & summary | %s %s |\n' "$(progress_icon "$MARK_PR")" "$(progress_label "$MARK_PR")"
  if [ -n "$DETAIL" ]; then
    printf '\n%s\n' "$DETAIL"
  fi
} >"$BODY_FILE"

if [ -z "$COMMENT_ID" ]; then
  RESP="$(jq -n --rawfile body "$BODY_FILE" '{body: $body}' | gh api -X POST "/repos/${REPO_FULL_NAME}/issues/${ISSUE_OR_PR}/comments" --input -)"
  COMMENT_ID="$(printf '%s' "$RESP" | jq -r '.id // empty')"
  if [ -z "$COMMENT_ID" ] || [ "$COMMENT_ID" = "null" ]; then
    echo "progress_comment_exit=1"
    echo "progress_comment_error=post_failed"
    exit 1
  fi
  echo "progress_comment_created=true"
else
  if ! jq -n --rawfile body "$BODY_FILE" '{body: $body}' | gh api -X PATCH "/repos/${REPO_FULL_NAME}/issues/comments/${COMMENT_ID}" --input -; then
    echo "progress_comment_exit=1"
    echo "progress_comment_error=patch_failed"
    exit 1
  fi
  echo "progress_comment_updated=true"
fi

echo "progress_comment_id=${COMMENT_ID}"
echo "progress_comment_url=https://github.com/${REPO_FULL_NAME}/issues/${ISSUE_OR_PR}#issuecomment-${COMMENT_ID}"
echo "progress_comment_exit=0"
