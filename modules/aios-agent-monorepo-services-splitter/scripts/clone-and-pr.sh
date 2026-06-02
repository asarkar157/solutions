#!/usr/bin/env bash
# Clone repo, create branch, commit docs, open PR — PR-only delivery (never push default branch).
set -euo pipefail

mirror_note() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  local value="${3:?VALUE}"
  local notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"
  jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$notes" >"${notes}.tmp" \
    && mv "${notes}.tmp" "$notes"
}

bootstrap_gh() {
  local git_token="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
  export GIT_TOKEN="$git_token" GH_TOKEN="$git_token" GITHUB_TOKEN="$git_token"
  export GIT_TERMINAL_PROMPT=0
  if [ -z "$git_token" ]; then
    echo "gh_env_present=false"
    return 1
  fi
  echo "gh_env_present=true"
  gh auth setup-git
  git config --global user.name "guild-monorepo-splitter"
  git config --global user.email "monorepo-splitter@stackgen.local"
}

git_clone_url() {
  local url="${1:?REPO_CLONE_URL}"
  # Plain URL only: bootstrap_gh configures the credential helper (shared sidecar — no PAT in .git/config).
  printf '%s' "$url"
}

cmd_clone() {
  local work_root="${1:?WORK_ROOT}"
  local repo_url="${2:?REPO_URL}"
  local default_branch="${3:-main}"

  bootstrap_gh || true
  mkdir -p "$work_root"
  [ -f "$work_root/notes.json" ] || echo '{}' >"$work_root/notes.json"

  local repo_dir="$work_root/repo"
  local effective_url
  effective_url="$(git_clone_url "$repo_url")"

  if [ -d "$repo_dir/.git" ]; then
    cd "$repo_dir"
    git fetch --all --prune
  else
    git clone "$effective_url" "$repo_dir"
    cd "$repo_dir"
  fi

  git checkout "$default_branch" 2>/dev/null || git checkout -b "$default_branch" "origin/$default_branch" 2>/dev/null || git checkout -b "$default_branch"
  git pull --ff-only origin "$default_branch" 2>/dev/null || true

  mirror_note "$work_root" "repo_clone_path" "$repo_dir"
  mirror_note "$work_root" "default_branch" "$default_branch"
  echo "repo_clone_path=${repo_dir}"
  echo "clone_ok=true"
}

cmd_create_branch() {
  local work_root="${1:?WORK_ROOT}"
  local branch_name="${2:?BRANCH_NAME}"
  local repo_dir="$work_root/repo"

  cd "$repo_dir"
  git checkout -b "$branch_name"
  mirror_note "$work_root" "working_branch" "$branch_name"
  echo "working_branch=${branch_name}"
}

cmd_commit_and_push() {
  local work_root="${1:?WORK_ROOT}"
  local commit_message="${2:?COMMIT_MESSAGE}"
  local repo_dir="$work_root/repo"
  local branch
  branch="$(jq -r '.working_branch // empty' "$work_root/notes.json" 2>/dev/null || true)"
  [ -n "$branch" ] || branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)"

  cd "$repo_dir"
  git add -A
  if git diff --cached --quiet; then
    mirror_note "$work_root" "commit_skipped" "no_changes"
    echo "commit_skipped=true"
    return 0
  fi
  git commit -m "$commit_message"
  git push -u origin "$branch"
  mirror_note "$work_root" "push_ok" "true"
  echo "push_ok=true"
}

cmd_open_pr() {
  local work_root="${1:?WORK_ROOT}"
  local title="${2:?PR_TITLE}"
  local body="${3:-Automated monorepo split guidance from Guild.}"
  local default_branch="${4:-main}"
  local repo_dir="$work_root/repo"
  local branch
  branch="$(jq -r '.working_branch // empty' "$work_root/notes.json" 2>/dev/null || true)"
  [ -n "$branch" ] || branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD)"

  bootstrap_gh || {
    mirror_note "$work_root" "pr_blocker" "gh_auth_missing"
    echo "pr_blocker=gh_auth_missing"
    exit 1
  }

  cd "$repo_dir"
  local pr_url
  pr_url="$(gh pr create --base "$default_branch" --head "$branch" --title "$title" --body "$body" 2>"$work_root/pr.err" || true)"
  if [ -z "$pr_url" ]; then
    mirror_note "$work_root" "pr_blocker" "gh_pr_create_failed"
    cat "$work_root/pr.err" >&2 || true
    echo "pr_blocker=gh_pr_create_failed"
    exit 1
  fi
  mirror_note "$work_root" "pr_url" "$pr_url"
  echo "pr_url=${pr_url}"
}

cmd_render_pr_body() {
  local work_root="${1:?WORK_ROOT}"
  local kind="${2:?KIND}"
  local repo_dir="$work_root/repo"
  local notes="$work_root/notes.json"
  local default_branch scaffold_count validated baseline

  default_branch="$(jq -r '.default_branch // "main"' "$notes" 2>/dev/null || echo "main")"
  scaffold_count="$(jq -r '.scaffold_service_count // "0"' "$notes" 2>/dev/null || echo "0")"
  validated="$(jq -r '.scaffold_layout_validated // "false"' "$notes" 2>/dev/null || echo "false")"
  baseline="$(jq -r '.baseline_test_run_evidence // .baseline_test_status // "not_collected"' "$notes" 2>/dev/null || echo "not_collected")"

  echo "## Guild monorepo split — ${kind}"
  echo ""
  echo "Automated PR from Guild workflow. **Only files in the commit diff below were generated** — do not assume undeclared artifacts exist."
  echo ""
  if [ "$kind" = "extract" ]; then
    echo "- Scaffold services: **${scaffold_count}**"
    echo "- Layout validated: **${validated}**"
    echo "- Baseline tests: **${baseline}**"
    echo ""
  fi
  echo "### Committed files"
  echo '```'
  if [ -d "$repo_dir/.git" ]; then
    git -C "$repo_dir" diff --cached --name-only 2>/dev/null || git -C "$repo_dir" diff --name-only HEAD~1..HEAD 2>/dev/null || true
  fi
  echo '```'
  echo ""
  echo "### Review checklist"
  if [ "$kind" = "guidance" ]; then
    echo "- [ ] \`docs/architecture/service-catalog.yaml\` lists every proposed service with rationale"
    echo "- [ ] \`docs/architecture/migration-phases.md\` defines strangler-fig order"
    echo "- [ ] \`AGENTS.md\` includes setup and test commands from scan"
    echo "- [ ] \`coupling-matrix.json\` present from boundary scan"
  else
    echo "- [ ] Each \`services/<name>/README.md\` describes ownership and test gate"
    echo "- [ ] JUnit / Go / Vitest stubs present under each service"
    echo "- [ ] Gradle settings include new \`services:*\` modules (if applicable)"
    echo "- [ ] Run baseline \`./gradlew test\` (or repo test command) before merge"
  fi
}

case "${1:-}" in
  clone) shift; cmd_clone "$@" ;;
  create-branch) shift; cmd_create_branch "$@" ;;
  commit-and-push) shift; cmd_commit_and_push "$@" ;;
  open-pr) shift; cmd_open_pr "$@" ;;
  render-pr-body) shift; cmd_render_pr_body "$@" ;;
  *)
    echo "usage: clone-and-pr.sh clone|create-branch|commit-and-push|open-pr ..." >&2
    exit 1
    ;;
esac
