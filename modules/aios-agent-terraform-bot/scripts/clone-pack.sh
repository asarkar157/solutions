#!/usr/bin/env bash
# Minimal terraform-bot clone pack — embed via ONE execute_series command:
#   /bin/bash -s clone WORK_ROOT URL BRANCH ISSUE PR_REF PR_URL <<'TFBOT_CLONE_PACK'
#   ...this file...
#   TFBOT_CLONE_PACK
# Guild execute_series runs each command via sh -c; the outer command MUST invoke /bin/bash -s (never bare sh function syntax).
set -euo pipefail

SCRIPT_PACK_VERSION="${SCRIPT_PACK_VERSION:-20260531.2}"

mirror_note() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  local value="${3:?VALUE}"
  local notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"
  jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$notes" >"${notes}.tmp" \
    && mv "${notes}.tmp" "$notes"
  echo "mirrored:${key}" >&2
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
  git config --global user.name "stackgen-terraform-bot"
  git config --global user.email "terraform-bot@stackgen.local"
}

git_clone_url() {
  local url="${1:?REPO_CLONE_URL}"
  local git_token="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
  if [[ "$url" =~ ^git@ ]]; then
    printf '%s' "$url"
    return 0
  fi
  if [[ "$url" =~ ^https://[^/@]+@ ]]; then
    printf '%s' "$url"
    return 0
  fi
  if [ -n "$git_token" ] && [[ "$url" =~ ^https://github\.com/ ]]; then
    printf 'https://x-access-token:%s@github.com/%s' "$git_token" "${url#https://github.com/}"
    return 0
  fi
  printf '%s' "$url"
}

git_with_auth_mode() {
  export GIT_TERMINAL_PROMPT=0
  if [ -n "${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}" ]; then
    git "$@"
    return $?
  fi
  git -c credential.helper= "$@"
}

remove_stale_clone_dir() {
  local repo_dir="${1:?REPO_DIR}"
  if [ -d "$repo_dir" ] && [ ! -d "$repo_dir/.git" ]; then
    rm -rf "$repo_dir"
  fi
}

cmd_clone() {
  local work_root="${1:?WORK_ROOT}"
  local repo_clone_url="${2:?REPO_CLONE_URL}"
  local default_branch="${3:?DEFAULT_BRANCH}"
  local issue_or_pr="${4:?ISSUE_OR_PR_NUMBER}"
  local pr_head_ref="${5:-}"
  local pr_head_clone_url="${6:-$repo_clone_url}"

  local gh_ok=false
  if bootstrap_gh; then
    gh_ok=true
  else
    echo "gh_env_present=false"
  fi

  mkdir -p "$work_root"
  [ -f "$work_root/notes.json" ] || echo '{}' >"$work_root/notes.json"

  local repo_dir="$work_root/repo"
  local effective_clone_url
  effective_clone_url="$(git_clone_url "$repo_clone_url")"
  remove_stale_clone_dir "$repo_dir"
  if [ -d "$repo_dir/.git" ]; then
    cd "$repo_dir"
    if ! git_with_auth_mode fetch --all --prune 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "network"
      echo "clone_blocker=network"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
  else
    mkdir -p "$(dirname "$repo_dir")"
    if ! git_with_auth_mode clone "$effective_clone_url" "$repo_dir" 2>"$work_root/clone.err"; then
      remove_stale_clone_dir "$repo_dir"
      if [ "$gh_ok" = "false" ]; then
        mirror_note "$work_root" "clone_blocker" "auth_or_network"
        echo "clone_blocker=auth_or_network"
      else
        mirror_note "$work_root" "clone_blocker" "network"
        echo "clone_blocker=network"
      fi
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
    cd "$repo_dir"
  fi

  if [ -n "$pr_head_ref" ] && [ "$pr_head_clone_url" != "$repo_clone_url" ]; then
    if ! git_with_auth_mode remote add fork "$pr_head_clone_url" 2>/dev/null; then
      git_with_auth_mode remote set-url fork "$pr_head_clone_url"
    fi
    if ! git_with_auth_mode fetch fork "$pr_head_ref:$pr_head_ref" 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "branch"
      echo "clone_blocker=branch"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
    if ! git switch "$pr_head_ref" 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "branch"
      echo "clone_blocker=branch"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
  elif [ -n "$pr_head_ref" ]; then
    if ! git_with_auth_mode fetch origin "pull/${issue_or_pr}/head:pr-${issue_or_pr}" 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "branch"
      echo "clone_blocker=branch"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
    if ! git switch "pr-${issue_or_pr}" 2>"$work_root/clone.err"; then
      mirror_note "$work_root" "clone_blocker" "branch"
      echo "clone_blocker=branch"
      cat "$work_root/clone.err" >&2 || true
      exit 1
    fi
  else
    if ! git switch "$default_branch" 2>/dev/null; then
      if ! git switch -c "$default_branch" "origin/$default_branch" 2>"$work_root/clone.err"; then
        mirror_note "$work_root" "clone_blocker" "branch"
        echo "clone_blocker=branch"
        cat "$work_root/clone.err" >&2 || true
        exit 1
      fi
    fi
  fi

  local sha
  sha="$(git rev-parse HEAD)"
  if [ "$gh_ok" = "true" ]; then
    mirror_note "$work_root" "clone_auth_mode" "token"
    mirror_note "$work_root" "push_requires_token" "false"
  else
    mirror_note "$work_root" "clone_auth_mode" "anonymous"
    mirror_note "$work_root" "push_requires_token" "true"
  fi
  mirror_note "$work_root" "repo_clone_path" "$repo_dir"
  mirror_note "$work_root" "repo_head_sha" "$sha"
  echo "repo_clone_path=$repo_dir"
  echo "repo_head_sha=$sha"
  echo "script_pack_version=$SCRIPT_PACK_VERSION"
}

cmd="${1:?command required}"
shift
case "$cmd" in
  clone) cmd_clone "$@" ;;
  *)
    echo "unknown_command=$cmd"
    exit 1
    ;;
esac
