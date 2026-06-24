#!/usr/bin/env bash
# Post a GitHub issue comment for blocked spec-symphony workflow runs.
set -euo pipefail

REPO_FULL_NAME="${REPO_FULL_NAME:-}"
ISSUE_OR_PR="${ISSUE_OR_PR:?set ISSUE_OR_PR}"

# Tolerate an unsubstituted placeholder (e.g. literal "<repository_full_name>") from the spawning agent.
case "$REPO_FULL_NAME" in *"<"*">"* | "") REPO_FULL_NAME="" ;; esac

# Fallback: derive owner/repo from the cloned repo's git remote when the agent did not supply it.
if [ -z "$REPO_FULL_NAME" ]; then
  for d in "${WORK_ROOT:-}/repo" "$PWD"; do
    [ -n "$d" ] && [ -d "$d/.git" ] || continue
    url="$(git -C "$d" config --get remote.origin.url 2>/dev/null || true)"
    REPO_FULL_NAME="$(printf '%s' "$url" | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')"
    [ -n "$REPO_FULL_NAME" ] && break
  done
fi

if [ -z "$REPO_FULL_NAME" ]; then
  echo "notify_blocker=missing_repo_full_name"
  echo "notify_exit=1"
  exit 1
fi
BODY="${COMMENT_BODY:-${BLOCKER_DETAIL:-Spec-symphony workflow blocked — see stage_summary notes.}}"

if ! [[ "$ISSUE_OR_PR" =~ ^[0-9]+$ ]]; then
  echo "notify_blocker=invalid_issue_number"
  echo "notify_exit=1"
  exit 1
fi

BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT
{
  printf '%s\n\n' "## Spec-symphony workflow blocked"
  printf '%s\n' "$BODY"
  printf '\n_Automated notification from spec-symphony-orchestrator._\n'
} >"$BODY_FILE"

if ! RESP="$(jq -n --rawfile body "$BODY_FILE" '{body: $body}' \
  | gh api -X POST "/repos/${REPO_FULL_NAME}/issues/${ISSUE_OR_PR}/comments" --input - 2>"$BODY_FILE.err")"; then
  if grep -qi 'Could not resolve to an issue' "$BODY_FILE.err" 2>/dev/null; then
    echo "notify_blocker=issue_not_found"
    echo "notify_exit=0"
    echo "hint=use_trigger_webhook_create_github_issue_for_real_issue_number"
    exit 0
  fi
  cat "$BODY_FILE.err" >&2 || true
  echo "notify_blocker=gh_api_failed"
  echo "notify_exit=1"
  exit 1
fi

CID="$(printf '%s' "$RESP" | jq -r '.id // empty')"
echo "notify_comment_id=${CID}"
echo "notify_exit=0"
echo "notify_posted=true"
