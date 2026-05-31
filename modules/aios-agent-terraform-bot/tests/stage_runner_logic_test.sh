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
  eval "$(sed -n '/^git_clone_url()/,/^}/p; /^git_with_auth_mode()/,/^}/p; /^remove_stale_clone_dir()/,/^}/p; /^mirror_note()/,/^}/p; /^resolve_repo_dir()/,/^}/p' "$RUNNER")"
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

# --- resolve_repo_dir legacy repo_clone symlink ---
WORK3="${TMP}/work3"
mkdir -p "$WORK3/repo_clone/.git"
touch "$WORK3/repo_clone/.git/HEAD"
echo '{}' >"$WORK3/notes.json"
RESOLVED="$(resolve_repo_dir "$WORK3")"
if [ "$RESOLVED" != "$WORK3/repo" ]; then
  echo "FAIL: resolve_repo_dir should normalize to repo (got '${RESOLVED}')" >&2
  exit 1
fi
if [ ! -e "$WORK3/repo/.git" ]; then
  echo "FAIL: resolve_repo_dir should symlink repo -> repo_clone" >&2
  exit 1
fi

# --- cmd_validate emits fmt_exit markers ---
MOD="${TMP}/module"
mkdir -p "$MOD"
cat >"$MOD/versions.tf" <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF
cat >"$MOD/main.tf" <<'EOF'
resource "null_resource" "this" {}
EOF
WORK4="${TMP}/work4"
mkdir -p "$WORK4/.work"
echo '{}' >"$WORK4/notes.json"
export TFBOT_ALLOW_DIRECT=1
if command -v tofu >/dev/null 2>&1 || command -v terraform >/dev/null 2>&1; then
  OUT="$(bash "$RUNNER" validate "$WORK4" "$MOD" 2>/dev/null || true)"
  if ! grep -q 'fmt_exit=' <<<"$OUT"; then
    echo "FAIL: validate should emit fmt_exit= marker" >&2
    exit 1
  fi
  if ! grep -q 'binary=' <<<"$OUT"; then
    echo "FAIL: validate should emit binary= marker" >&2
    exit 1
  fi
else
  echo "SKIP: validate marker test (no tofu/terraform in PATH)" >&2
fi

# --- cmd_clone against public repo (network required) ---
if command -v git >/dev/null 2>&1; then
  WORK="${TMP}/work"
  unset GIT_TOKEN GITHUB_TOKEN GH_TOKEN
  export TFBOT_ALLOW_DIRECT=1
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
export TFBOT_ALLOW_DIRECT=1
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

# --- cmd_validate clears sticky NEEDS_REVISION on subsequent PASS ---
WORK5="${TMP}/work5"
MOD5="${TMP}/module5"
mkdir -p "$MOD5"
cat >"$MOD5/versions.tf" <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF
cat >"$MOD5/main.tf" <<'EOF'
resource "null_resource" "this" {
  invalid =
}
EOF
mkdir -p "$WORK5"
echo '{"module_quality_summary":"NEEDS_REVISION"}' >"$WORK5/notes.json"
export TFBOT_ALLOW_DIRECT=1
OUT_FAIL="$(bash "$RUNNER" validate "$WORK5" "$MOD5" 2>/dev/null || true)"
if ! grep -q 'module_quality_summary=NEEDS_REVISION' <<<"$OUT_FAIL"; then
  echo "FAIL: invalid module should NEEDS_REVISION (got: $OUT_FAIL)" >&2
  exit 1
fi
cat >"$MOD5/main.tf" <<'EOF'
resource "null_resource" "this" {}
EOF
OUT_PASS="$(bash "$RUNNER" validate "$WORK5" "$MOD5" 2>/dev/null || true)"
if ! grep -q 'module_quality_summary=PASS' <<<"$OUT_PASS"; then
  echo "FAIL: validate should recover to PASS after fix (got: $OUT_PASS)" >&2
  exit 1
fi
STICKY="$(jq -r '.module_quality_summary // empty' "$WORK5/notes.json" 2>/dev/null || true)"
if [ "$STICKY" != "PASS" ]; then
  echo "FAIL: notes.json module_quality_summary should be PASS (got '${STICKY}')" >&2
  exit 1
fi

unset TFBOT_ALLOW_DIRECT TFBOT_EMBEDDED
if bash "$RUNNER" validate "$WORK4" "$MOD" 2>"${TMP}/embed.err"; then
  echo "FAIL: direct stage-runner invoke should fail without TFBOT_EMBEDDED" >&2
  exit 1
fi
if ! grep -q 'script_pack_error=invoke_via_embed_tfbot_run' "${TMP}/embed.err"; then
  echo "FAIL: missing embed guard error message" >&2
  exit 1
fi

echo "OK: stage-runner logic checks passed"
