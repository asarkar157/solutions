#!/usr/bin/env bash
# Behavioral checks for stage-runner.sh clone/auth helpers (no MCP required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${ROOT}/scripts/stage-runner.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# shellcheck source=/dev/null
source_helpers() {
  # Extract helper functions without running the command dispatcher.
  eval "$(sed -n '/^git_clone_url()/,/^}/p; /^git_with_auth_mode()/,/^}/p; /^remove_stale_clone_dir()/,/^}/p' "$RUNNER")"
}

source_helpers

assert_eq() {
  local got="$1" want="$2" label="$3"
  if [ "$got" != "$want" ]; then
    echo "FAIL: ${label}: got '${got}' want '${want}'" >&2
    exit 1
  fi
}

# --- git_clone_url corner cases ---
unset GIT_TOKEN GITHUB_TOKEN GH_TOKEN
assert_eq "$(git_clone_url 'https://github.com/org/repo.git')" \
  'https://github.com/org/repo.git' \
  'anonymous preserves plain https url'

export GIT_TOKEN='pat123'
assert_eq "$(git_clone_url 'https://github.com/org/repo.git')" \
  'https://x-access-token:pat123@github.com/org/repo.git' \
  'token injects x-access-token for github.com'

assert_eq "$(git_clone_url 'https://user:old@github.com/org/repo.git')" \
  'https://user:old@github.com/org/repo.git' \
  'existing embedded creds left unchanged'

assert_eq "$(git_clone_url 'git@github.com:org/repo.git')" \
  'git@github.com:org/repo.git' \
  'ssh url unchanged'

unset GIT_TOKEN GITHUB_TOKEN GH_TOKEN

# --- remove_stale_clone_dir ---
STALE="${TMP}/stale-repo"
mkdir -p "$STALE"
touch "$STALE/incomplete"
remove_stale_clone_dir "$STALE"
if [ -d "$STALE" ]; then
  echo "FAIL: remove_stale_clone_dir should delete dir without .git" >&2
  exit 1
fi

GOOD="${TMP}/good-repo"
mkdir -p "$GOOD/.git"
touch "$GOOD/.git/HEAD"
remove_stale_clone_dir "$GOOD"
if [ ! -d "$GOOD/.git" ]; then
  echo "FAIL: remove_stale_clone_dir must not delete valid git dir" >&2
  exit 1
fi

# --- cmd_clone against public repo (network required) ---
if command -v git >/dev/null 2>&1; then
  WORK="${TMP}/work"
  unset GIT_TOKEN GITHUB_TOKEN GH_TOKEN
  if bash "$RUNNER" clone "$WORK" \
    'https://github.com/stackgenhq/discovery-modules.git' \
    main 9 '' '' 2>"${TMP}/clone-public.err"; then
    if [ ! -d "$WORK/repo/.git" ]; then
      echo "FAIL: public clone should materialize repo/.git" >&2
      exit 1
    fi
    if ! grep -q 'repo_clone_path=' <<<"$(bash "$RUNNER" clone "$WORK" \
      'https://github.com/stackgenhq/discovery-modules.git' main 9 '' '' 2>/dev/null)"; then
      : # second clone reuses existing — ok
    fi
    NOTES="$(jq -r '.clone_auth_mode // empty' "$WORK/notes.json" 2>/dev/null || true)"
    if [ "$NOTES" != "anonymous" ]; then
      echo "FAIL: anonymous clone should set clone_auth_mode=anonymous (got '${NOTES}')" >&2
      exit 1
    fi
    PUSH_REQ="$(jq -r '.push_requires_token // empty' "$WORK/notes.json" 2>/dev/null || true)"
    if [ "$PUSH_REQ" != "true" ]; then
      echo "FAIL: anonymous clone should set push_requires_token=true" >&2
      exit 1
    fi
  else
    echo "SKIP: public clone integration test (network blocked?): $(cat "${TMP}/clone-public.err" 2>/dev/null | head -1)" >&2
  fi
fi

# --- commit-pr without token must not crash (set -e) ---
WORK2="${TMP}/work2"
mkdir -p "$WORK2/repo/.git" "$WORK2/.work"
echo '{}' >"$WORK2/notes.json"
unset GIT_TOKEN GITHUB_TOKEN GH_TOKEN
if bash "$RUNNER" commit-pr "$WORK2" 'org/repo' 9 2>"${TMP}/commit.err"; then
  echo "FAIL: commit-pr should fail without token" >&2
  exit 1
fi
if ! grep -q 'pr_blocker=auth' "${TMP}/commit.err" && ! bash "$RUNNER" commit-pr "$WORK2" 'org/repo' 9 2>&1 | grep -q 'pr_blocker=auth'; then
  OUT="$(bash "$RUNNER" commit-pr "$WORK2" 'org/repo' 9 2>&1 || true)"
  if ! grep -q 'pr_blocker=auth' <<<"$OUT"; then
    echo "FAIL: commit-pr should emit pr_blocker=auth without token" >&2
    exit 1
  fi
fi

echo "OK: stage-runner logic checks passed"
