#!/usr/bin/env bash
# spec-symphony clone pack — clone target repo into WORK_ROOT/repo
set -euo pipefail

SCRIPT_PACK_VERSION="${SCRIPT_PACK_VERSION:-20260616.5}"

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

validate_work_root() {
  local wr
  wr="$(normalize_work_root "${1:?work_root}")"
  case "$wr" in
    *'{'*|*'}'*|*'$'*|*" "*)
      echo "clone_blocker=malformed_work_root"
      echo "error=malformed_work_root reason=illegal_chars path=$wr"
      echo "hint=use spawn-context WORK_ROOT={{work_root}} verbatim — FORBIDDEN: \$HOME/.wf-* or \$HOME}/"
      return 1
      ;;
  esac
  if [[ ! "$wr" =~ ^/ ]]; then
    echo "clone_blocker=malformed_work_root"
    echo "error=malformed_work_root reason=not_absolute path=$wr"
    return 1
  fi
  if [[ "$wr" =~ //[a-zA-Z] ]]; then
    echo "clone_blocker=malformed_work_root"
    echo "error=malformed_work_root reason=double_slash path=$wr"
    return 1
  fi
  return 0
}

mirror_note() {
  local work_root key value notes
  work_root="$(normalize_work_root "${1:?WORK_ROOT}")"
  key="${2:?KEY}"
  value="${3:?VALUE}"
  notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"
  jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$notes" >"${notes}.tmp" \
    && mv "${notes}.tmp" "$notes"
}

bootstrap_gh() {
  local git_token="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
  export GIT_TOKEN="$git_token" GH_TOKEN="$git_token" GITHUB_TOKEN="$git_token"
  export GIT_TERMINAL_PROMPT=0
  [ -n "$git_token" ] || return 1
  gh auth setup-git 2>/dev/null || true
  git config --global user.name "stackgen-spec-symphony"
  git config --global user.email "spec-symphony@stackgen.local"
}

git_clone_url() {
  local url="${1:?REPO_CLONE_URL}"
  local git_token="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
  if [[ "$url" =~ ^https://github\.com/ ]] && [ -n "$git_token" ] && [[ ! "$url" =~ ^https://[^/@]+@ ]]; then
    printf 'https://x-access-token:%s@github.com/%s' "$git_token" "${url#https://github.com/}"
    return 0
  fi
  printf '%s' "$url"
}

cmd_clone() {
  local work_root repo_clone_url default_branch issue_or_pr

  if [ -n "${WORK_ROOT:-}" ]; then
    work_root="$(normalize_work_root "$WORK_ROOT")"
  elif [ -n "${1:-}" ]; then
    work_root="$(normalize_work_root "$1")"
    shift
  else
    echo "clone_blocker=missing_clone_params"
    echo "error=missing WORK_ROOT env or work_root arg"
    exit 1
  fi

  validate_work_root "$work_root" || exit 1
  export WORK_ROOT="$work_root"

  repo_clone_url="${REPO_CLONE_URL:-${1:-}}"
  default_branch="${DEFAULT_BRANCH:-${2:-main}}"
  issue_or_pr="${ISSUE_OR_PR:-${3:-}}"

  if [ -z "$repo_clone_url" ]; then
    echo "clone_blocker=missing_clone_params"
    echo "error=missing REPO_CLONE_URL"
    exit 1
  fi

  case "$repo_clone_url" in
    *example.com/example*|*github.com/example/*|*github.com/example.git*)
      echo "clone_blocker=placeholder_url"
      mirror_note "$work_root" "clone_blocker" "placeholder_url" || true
      exit 1
      ;;
  esac

  bootstrap_gh || echo "gh_env_present=false"
  mkdir -p "$work_root"
  [ -f "$work_root/notes.json" ] || echo '{}' >"$work_root/notes.json"

  local repo_dir="$work_root/repo"
  if [[ "$repo_dir" =~ [{}] ]] || [[ "$repo_dir" != */repo ]]; then
    mirror_note "$work_root" "clone_blocker" "malformed_work_root"
    echo "clone_blocker=malformed_work_root"
    echo "error=malformed_repo_dir path=$repo_dir"
    exit 1
  fi
  local effective_clone_url
  effective_clone_url="$(git_clone_url "$repo_clone_url")"
  if [ -d "$repo_dir/.git" ]; then
    cd "$repo_dir"
    git fetch --all --prune 2>"$work_root/clone.err" || {
      mirror_note "$work_root" "clone_blocker" "network"
      echo "clone_blocker=network"
      exit 1
    }
  else
    mkdir -p "$(dirname "$repo_dir")"
    git clone "$effective_clone_url" "$repo_dir" 2>"$work_root/clone.err" || {
      mirror_note "$work_root" "clone_blocker" "auth_or_network"
      echo "clone_blocker=auth_or_network"
      exit 1
    }
    cd "$repo_dir"
  fi

  if [ -n "$issue_or_pr" ] && [[ "$issue_or_pr" =~ ^[0-9]+$ ]]; then
    git fetch origin "pull/${issue_or_pr}/head:pr-${issue_or_pr}" 2>/dev/null \
      && git switch "pr-${issue_or_pr}" 2>/dev/null || git switch "$default_branch" 2>/dev/null || true
  else
    git switch "$default_branch" 2>/dev/null \
      || git switch -c "$default_branch" "origin/$default_branch" 2>/dev/null || true
  fi

  local sha
  sha="$(git rev-parse HEAD)"
  mirror_note "$work_root" "repo_clone_path" "$repo_dir"
  mirror_note "$work_root" "repo_head_sha" "$sha"
  echo "repo_clone_path=$repo_dir"
  echo "repo_head_sha=$sha"
  echo "script_pack_version=${SCRIPT_PACK_VERSION}"
  echo "stage_summary:intake-clone-bootstrap=done"
}

cmd="${1:?command}"
shift
case "$cmd" in
  clone) cmd_clone "$@" ;;
  *) echo "unknown_command=$cmd"; exit 1 ;;
esac
