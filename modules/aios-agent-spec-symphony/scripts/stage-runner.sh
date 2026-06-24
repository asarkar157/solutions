#!/usr/bin/env bash
# spec-symphony stage runner — clone | spec-bootstrap | author-spec | cursor-* | validate | commit-pr | archive
set -euo pipefail

SCRIPT_PACK_VERSION="${SCRIPT_PACK_VERSION:-20260616.5}"
PACK_DIR="${SPECSYM_PACK_DIR:-$(dirname "$0")}"

# Expands literal $HOME tokens agents sometimes paste instead of {{work_root}}.
normalize_work_root() {
  local wr="${1:?work_root}"
  if [[ "$wr" == *"\$HOME"* ]]; then
    wr="${wr//\$HOME/${HOME}}"
  fi
  if [[ "$wr" == *"\${HOME}"* ]]; then
    wr="${wr//\${HOME}/${HOME}}"
  fi
  printf '%s' "$wr"
}

require_direct() {
  [ "${SPECSYM_ALLOW_DIRECT:-}" = "1" ] || {
    echo "script_pack_error=set_SPECSYM_ALLOW_DIRECT=1"
    exit 1
  }
}

feature_id_from_branch() {
  local branch="${1:-}"
  local fid
  fid="$(printf '%s' "$branch" | grep -oE '([A-Z]+-[0-9]+)' | head -1 || true)"
  [ -n "$fid" ] && printf '%s' "$fid" || printf '%s' "$branch"
}

cmd_clone() {
  require_direct
  exec "${PACK_DIR}/clone-pack.sh" clone "$@"
}

cmd_spec_bootstrap() {
  require_direct
  local work_root repo_dir fw change_type
  work_root="$(normalize_work_root "${1:?WORK_ROOT}")"
  repo_dir="${2:-$work_root/repo}"
  fw="${3:-auto}"
  change_type="${4:-brownfield}"
  SDD_FRAMEWORK="$fw" CHANGE_TYPE="$change_type" SPECSYM_PACK_DIR="$PACK_DIR" \
    "${PACK_DIR}/spec-bootstrap.sh" "$repo_dir"
}

cmd_author_spec() {
  require_direct
  local work_root repo_dir fw change_type
  work_root="$(normalize_work_root "${1:?WORK_ROOT}")"
  repo_dir="${2:-$work_root/repo}"
  fw="${3:-auto}"
  change_type="${4:-brownfield}"
  SDD_FRAMEWORK="$fw" CHANGE_TYPE="$change_type" FEATURE_ID="${FEATURE_ID:-}" \
    ISSUE_TITLE="${ISSUE_TITLE:-}" ISSUE_BODY="${ISSUE_BODY:-}" ISSUE_OR_PR="${ISSUE_OR_PR:-}" \
    SPECSYM_PACK_DIR="$PACK_DIR" \
    "${PACK_DIR}/author-spec.sh" "$repo_dir"
}

cmd_cursor_author_spec() {
  require_direct
  local work_root repo_dir fid title body
  work_root="$(normalize_work_root "${1:?WORK_ROOT}")"
  repo_dir="${2:-$work_root/repo}"
  fid="${3:-${FEATURE_ID:-}}"
  title="${4:-${ISSUE_TITLE:-Spec-driven feature}}"
  body="${5:-${ISSUE_BODY:-}}"
  SPECSYM_PACK_DIR="$PACK_DIR" "${PACK_DIR}/cursor-author-spec.sh" "$repo_dir" "$fid" "$title" "$body"
}

cmd_cursor_implement() {
  require_direct
  local work_root repo_dir tasks ticket
  work_root="$(normalize_work_root "${1:?WORK_ROOT}")"
  repo_dir="${2:-$work_root/repo}"
  tasks="${3:-tasks.md}"
  ticket="${4:-${ISSUE_OR_PR:-}}"
  SPECSYM_PACK_DIR="$PACK_DIR" "${PACK_DIR}/cursor-implement.sh" "$repo_dir" "$tasks" "$ticket"
}

cmd_linear_materialize() {
  require_direct
  local work_root repo_dir fid
  work_root="$(normalize_work_root "${1:?WORK_ROOT}")"
  repo_dir="${2:-$work_root/repo}"
  fid="${3:?feature_id}"
  if [ -z "${SPEC_MARKDOWN:-}" ] && [ -f "$work_root/spec_markdown.txt" ]; then
    SPEC_MARKDOWN="$(cat "$work_root/spec_markdown.txt")"
  fi
  if [ -z "${ENGINEERING_SUBGOALS:-}" ] && [ -f "$work_root/engineering_subgoals.txt" ]; then
    ENGINEERING_SUBGOALS="$(cat "$work_root/engineering_subgoals.txt")"
  fi
  SPECSYM_PACK_DIR="$PACK_DIR" "${PACK_DIR}/linear-spec-materialize.sh" "$repo_dir" "$fid"
}

cmd_validate() {
  require_direct
  local work_root repo_dir pr_num
  work_root="$(normalize_work_root "${1:?WORK_ROOT}")"
  repo_dir="${2:-$work_root/repo}"
  pr_num="${3:-}"
  "${PACK_DIR}/validate.sh" "$repo_dir" "$pr_num"
}

cmd_commit_pr() {
  require_direct
  local work_root repo_dir base_branch issue_or_pr title body
  work_root="$(normalize_work_root "${1:?WORK_ROOT}")"
  repo_dir="${2:-$work_root/repo}"
  base_branch="${3:-main}"
  issue_or_pr="${4:-}"
  title="${5:-Spec-driven feature implementation}"
  body="${6:-Automated PR from spec-symphony workflow. Links spec/change folder in description.}"

  cd "$repo_dir"

  # Feature slug for branch + spec-link lookup: prefer an explicit feature id, else the issue number.
  local slug
  slug="${FEATURE_ID:-}"
  [ -n "$slug" ] || slug="$issue_or_pr"
  [ -n "$slug" ] || slug="$(date +%Y%m%d%H%M%S)"

  # Per-run uniqueness token from the workflow scratch dir (".wf-<run-id>"), falling back to a timestamp.
  # Without this, every run for the same issue reuses one branch name and the second push is rejected
  # as a non-fast-forward against the branch the prior run already pushed.
  local run_token
  run_token="$(basename "$work_root" | sed -E 's/^\.wf-(spec-driven-feature-)?//' | tr -cd 'a-zA-Z0-9' | tail -c 12)"
  [ -n "$run_token" ] || run_token="$(date +%H%M%S)"

  # Never commit straight to the base branch: cut a unique feature branch off the current HEAD.
  # gh pr create requires head != base, so committing on main always produced an empty pr_url.
  local branch
  branch="$(git branch --show-current)"
  if [ -z "$branch" ] || [ "$branch" = "$base_branch" ]; then
    branch="spec-symphony/${slug}-${run_token}"
    git checkout -B "$branch"
  fi

  # Link the spec/change folder in the PR body. Try the branch feature id, then the slug/issue number.
  local fid spec_link key
  fid="$(feature_id_from_branch "$branch")"
  spec_link=""
  for key in "$fid" "$slug" "$issue_or_pr"; do
    [ -n "$key" ] || continue
    if [ -d "openspec/changes/$key" ]; then spec_link="openspec/changes/$key"; break; fi
    if [ -d "aidlc-docs/$key" ]; then spec_link="aidlc-docs/$key"; break; fi
    if [ -d "specs/$key" ]; then spec_link="specs/$key"; break; fi
  done
  [ -n "$spec_link" ] || spec_link="(see branch $branch)"
  body="${body}

Spec reference: ${spec_link}"

  git add -A
  if git diff --cached --quiet; then
    echo "pr_url="
    echo "working_branch=$branch"
    echo "stage_summary:create-pr=skipped_no_changes"
    exit 0
  fi
  git commit -m "$title"
  git push -u origin "$branch" 2>"$work_root/push.err" || {
    echo "stage_summary:create-pr=blocked"
    echo "push_error=failed"
    exit 1
  }
  local pr_url
  pr_url="$(gh pr create --base "$base_branch" --head "$branch" --title "$title" --body "$body" 2>"$work_root/pr.err" || true)"
  echo "pr_url=$pr_url"
  echo "working_branch=$branch"
  echo "stage_summary:create-pr=done"
  if [ -n "$issue_or_pr" ] && [ -n "${REPO_FULL_NAME:-}" ]; then
    gh issue comment "$issue_or_pr" --repo "$REPO_FULL_NAME" --body "Spec-symphony PR: $pr_url" 2>/dev/null || true
  fi
}

cmd_archive() {
  require_direct
  local work_root repo_dir fw
  work_root="$(normalize_work_root "${1:?WORK_ROOT}")"
  repo_dir="${2:-$work_root/repo}"
  fw="${3:-auto}"
  cd "$repo_dir"
  if [ "$fw" = "openspec" ] || [ -d openspec/changes ]; then
    openspec archive --yes 2>/dev/null || echo "archive_skipped=openspec_not_ready"
  fi
  echo "stage_summary:archive-specs=done"
}

cmd="${1:?command}"
shift
case "$cmd" in
  clone) cmd_clone "$@" ;;
  spec-bootstrap) cmd_spec_bootstrap "$@" ;;
  author-spec) cmd_author_spec "$@" ;;
  cursor-author-spec) cmd_cursor_author_spec "$@" ;;
  cursor-implement) cmd_cursor_implement "$@" ;;
  linear-materialize) cmd_linear_materialize "$@" ;;
  validate) cmd_validate "$@" ;;
  commit-pr) cmd_commit_pr "$@" ;;
  archive) cmd_archive "$@" ;;
  *)
    echo "unknown_command=$cmd"
    exit 1
    ;;
esac
