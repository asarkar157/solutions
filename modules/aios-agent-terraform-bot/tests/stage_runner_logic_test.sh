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
  if ! grep -q 'validate_started=true' <<<"$OUT"; then
    echo "FAIL: validate should emit validate_started=true marker" >&2
    exit 1
  fi
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

# --- discovery-scaffold on exact match re-runs validate (no early exit) ---
WORK6="${TMP}/work6"
mkdir -p "$WORK6/repo/aws/existing_mod" "$WORK6/.work"
mkdir -p "$WORK6/repo/.git"
touch "$WORK6/repo/.git/HEAD"
echo '{}' >"$WORK6/notes.json"
cat >"$WORK6/repo/aws/existing_mod/versions.tf" <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF
cat >"$WORK6/repo/aws/existing_mod/main.tf" <<'EOF'
resource "null_resource" "this" {}
EOF
export TFBOT_ALLOW_DIRECT=1
export MODULE_DIR=existing_mod
export PROVIDER_ROOT=aws
export SIBLING_DIR=existing_mod
OUT_EXACT="$(bash "$RUNNER" discovery-scaffold "$WORK6" 2>/dev/null || true)"
if ! grep -q 'scaffold_summary=existing_module_revalidated' <<<"$OUT_EXACT"; then
  echo "FAIL: exact discovery-scaffold should revalidate (got: $OUT_EXACT)" >&2
  exit 1
fi
if ! grep -q 'module_resolution_confidence=exact' <<<"$OUT_EXACT"; then
  echo "FAIL: exact discovery-scaffold should keep exact confidence" >&2
  exit 1
fi
if ! grep -q 'discovery_greenfield_validated=true' <<<"$OUT_EXACT"; then
  echo "FAIL: exact discovery-scaffold should emit discovery_greenfield_validated=true" >&2
  exit 1
fi
if command -v tofu >/dev/null 2>&1 || command -v terraform >/dev/null 2>&1; then
  if ! grep -q 'fmt_exit=' <<<"$OUT_EXACT"; then
    echo "FAIL: exact discovery-scaffold should emit fmt_exit from inline validate" >&2
    exit 1
  fi
fi

# --- pick_discovery_sibling_dir prefers token overlap over first_subdir ---
WORK7="${TMP}/work7"
mkdir -p "$WORK7/repo/aws/aws_alpha_widget" "$WORK7/repo/aws/aws_beta_other" "$WORK7/repo/aws/aws_zeta_iam_role"
for d in aws_alpha_widget aws_beta_other aws_zeta_iam_role; do
  mkdir -p "$WORK7/repo/aws/$d"
  echo 'terraform { required_version = ">= 1.0.0" }' >"$WORK7/repo/aws/$d/versions.tf"
done
PICK="$(bash -c 'source "'"$RUNNER"' 2>/dev/null; pick_discovery_sibling_dir "'"$WORK7/repo/aws"'" aws_alpha_widget_extra ""' 2>/dev/null || bash "$RUNNER" 2>/dev/null; true)"
# pick_discovery_sibling_dir is not exported from runner when sourced - test via discovery-scaffold env
export TFBOT_ALLOW_DIRECT=1
export ISSUE_TITLE='Add aws_alpha_widget_extra module'
export ISSUE_BODY='extra widget'
export ISSUE_OR_PR=99
export MODULE_DIR=aws_alpha_widget_extra
export PROVIDER_ROOT=aws
OUT_PICK="$(bash "$RUNNER" discovery-scaffold "$WORK7" 2>/dev/null || true)"
if grep -q 'scaffold_error=no_repo_clone' <<<"$OUT_PICK"; then
  mkdir -p "$WORK7/repo/.git"
  touch "$WORK7/repo/.git/HEAD"
  OUT_PICK="$(bash "$RUNNER" discovery-scaffold "$WORK7" 2>/dev/null || true)"
fi
if grep -q 'copied_sibling=aws_zeta_iam_role' <<<"$OUT_PICK"; then
  echo "FAIL: sibling pick should prefer aws_alpha_widget over aws_zeta_iam_role (got: $OUT_PICK)" >&2
  exit 1
fi
if ! grep -q 'copied_sibling=aws_alpha_widget' <<<"$OUT_PICK"; then
  echo "FAIL: expected copied_sibling=aws_alpha_widget (got: $OUT_PICK)" >&2
  exit 1
fi

# --- validate emits test_summary_tail on failure ---
WORK8="${TMP}/work8"
mkdir -p "$WORK8/.work"
MOD8="$WORK8/mod"
mkdir -p "$MOD8"
cat >"$MOD8/versions.tf" <<'EOF'
terraform {
  required_version = ">= 1.5.0"
}
EOF
cat >"$MOD8/main.tf" <<'EOF'
resource "null_resource" "bad" {
  triggers = { x = 1 }
}
EOF
mkdir -p "$MOD8/tests"
cat >"$MOD8/tests/fail.tftest.hcl" <<'EOF'
run "always_fail" {
  command = plan
  assert {
    condition     = false
    error_message = "intentional test failure for stage-runner"
  }
}
EOF
OUT_TEST="$(bash "$RUNNER" validate "$WORK8" "$MOD8" 2>/dev/null || true)"
if command -v tofu >/dev/null 2>&1 || command -v terraform >/dev/null 2>&1; then
  if ! grep -q 'test_summary_file=' <<<"$OUT_TEST"; then
    echo "FAIL: validate should emit test_summary_file on test failure (got: $OUT_TEST)" >&2
    exit 1
  fi
  if ! grep -q 'test_summary_tail=' <<<"$OUT_TEST"; then
    echo "FAIL: validate should emit test_summary_tail on test failure" >&2
    exit 1
  fi
fi

# --- commit-pr reads working_branch from notes (same PR head on rework) ---
eval "$(sed -n '/^note_val()/,/^}/p' "$RUNNER")"
WORK_BRANCH="${TMP}/work-branch"
mkdir -p "$WORK_BRANCH"
echo '{"working_branch":"terraform-bot/reuse-me"}' >"$WORK_BRANCH/notes.json"
branch="$(note_val "$WORK_BRANCH" working_branch)"
assert_eq "$branch" "terraform-bot/reuse-me" "commit-pr should read working_branch from notes"

# --- PR eligibility: fmt+validate pass opens PR even when tests fail ---
eval "$(sed -n '/^validate_out_fmt_validate_pass()/,/^}/p; /^should_open_pr_after_validate()/,/^}/p' "$RUNNER")"
VF="${TMP}/validate-pr-eligible.out"
cat >"$VF" <<'EOF'
fmt_exit=0
init_exit=0
validate_exit=0
test_exit=1
module_quality_summary=NEEDS_REVISION
EOF
validate_out_fmt_validate_pass "$VF" || {
  echo "FAIL: fmt+validate pass should be detected with test_exit=1" >&2
  exit 1
}
should_open_pr_after_validate "$VF" "true" || {
  echo "FAIL: should open PR when fmt+validate pass and defer_pr=true" >&2
  exit 1
}
sed -i.bak 's/^validate_exit=0/validate_exit=1/' "$VF"
rm -f "${VF}.bak"
if should_open_pr_after_validate "$VF" "true"; then
  echo "FAIL: should defer PR when validate_exit=1" >&2
  exit 1
fi
cat >"$VF" <<'EOF'
fmt_exit=0
init_exit=1
validate_exit=1
test_exit=1
module_quality_summary=NEEDS_REVISION
EOF
if should_open_pr_after_validate "$VF" "true" || should_open_pr_after_validate "$VF" "false"; then
  echo "FAIL: must not open PR when init/validate failed (defer true or false)" >&2
  exit 1
fi
cat >"$VF" <<'EOF'
fmt_exit=0
init_exit=0
validate_exit=0
test_exit=1
module_quality_summary=NEEDS_REVISION
EOF
should_open_pr_after_validate "$VF" "true" || {
  echo "FAIL: defer true should open PR when only tests fail" >&2
  exit 1
}
if should_open_pr_after_validate "$VF" "false"; then
  echo "FAIL: defer false should wait for PASS when tests fail" >&2
  exit 1
fi

unset TFBOT_ALLOW_DIRECT TFBOT_EMBEDDED MODULE_DIR PROVIDER_ROOT SIBLING_DIR ISSUE_TITLE ISSUE_BODY ISSUE_OR_PR
if bash "$RUNNER" validate "$WORK4" "$MOD" 2>"${TMP}/embed.err"; then
  echo "FAIL: direct stage-runner invoke should fail without TFBOT_EMBEDDED" >&2
  exit 1
fi
if ! grep -q 'script_pack_error=invoke_via_embed_tfbot_run' "${TMP}/embed.err"; then
  echo "FAIL: missing embed guard error message" >&2
  exit 1
fi

echo "OK: stage-runner logic checks passed"
