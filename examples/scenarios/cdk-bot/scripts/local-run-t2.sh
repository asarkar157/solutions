#!/usr/bin/env bash
# local-run-t2.sh — blackbox local run for workflow test T2 (KMS on lib/sample-stack.ts).
# Exercises clone-pack → implement-app → validate (with one loop-back for test + cdk.json).
#
# Usage:
#   ./scripts/local-run-t2.sh
#   ./scripts/local-run-t2.sh --payload-file issue.json
#   ./scripts/local-run-t2.sh --payload '{"action":"opened",...}'
#   ./scripts/local-run-t2.sh --keep-workdir   # do not rm WORK_ROOT on exit
#
# Requires: bash, git, jq, rg, node/npm (validate installs deps via bootstrap-deps.sh).
set -euo pipefail

SCENARIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${SCENARIO_DIR}/../../.." && pwd)"
MOD="${REPO_ROOT}/modules/aios-agent-cdk-bot"
PACK="${MOD}/scripts"
KEEP_WORKDIR=false
PAYLOAD=""

DEFAULT_PAYLOAD='{
  "action": "opened",
  "issue": {
    "number": 1,
    "title": "Fix encryption on SampleStack",
    "body": "Enable KMS encryption on the S3 bucket in lib/sample-stack.ts. Re-trigger after pack 20260616.11 deploy.",
    "state": "open",
    "user": { "login": "cdk-bot-tester" },
    "labels": []
  },
  "repository": {
    "full_name": "sks/cdk-typescript-demo",
    "name": "cdk-typescript-demo",
    "owner": { "login": "sks" },
    "clone_url": "https://github.com/sks/cdk-typescript-demo.git",
    "default_branch": "main"
  }
}'

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --keep-workdir) KEEP_WORKDIR=true; shift ;;
    --payload-file)
      [ $# -ge 2 ] || { echo "missing path after --payload-file" >&2; exit 1; }
      PAYLOAD="$(cat "$2")"
      shift 2
      ;;
    --payload)
      [ $# -ge 2 ] || { echo "missing JSON after --payload" >&2; exit 1; }
      PAYLOAD="$2"
      shift 2
      ;;
    *) echo "unknown arg: $1" >&2; usage 1 ;;
  esac
done

if [ -z "$PAYLOAD" ]; then
  PAYLOAD="$DEFAULT_PAYLOAD"
fi

command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }
command -v rg >/dev/null || { echo "rg required" >&2; exit 1; }

CLONE_URL="$(printf '%s' "$PAYLOAD" | jq -r '.repository.clone_url // empty')"
BRANCH="$(printf '%s' "$PAYLOAD" | jq -r '.repository.default_branch // "main"')"
ISSUE_NUM="$(printf '%s' "$PAYLOAD" | jq -r '.issue.number // .pull_request.number // empty')"
ISSUE_BODY="$(printf '%s' "$PAYLOAD" | jq -r '.issue.body // .pull_request.body // ""')"
REPO_FULL="$(printf '%s' "$PAYLOAD" | jq -r '.repository.full_name // empty')"

if [ -z "$CLONE_URL" ] || [ -z "$ISSUE_NUM" ]; then
  echo "payload must include repository.clone_url and issue.number" >&2
  exit 1
fi

PACK_VERSION="$(bash "${PACK}/read-script-pack-version.sh")"
WORK_ROOT="${WORK_ROOT:-/tmp/cdk-bot-local-t2-$(date +%s)}"
export CDKBOT_ALLOW_DIRECT=1
export CDKBOT_PACK_DIR="$PACK"
export SCRIPT_PACK_VERSION="$PACK_VERSION"

cleanup() {
  if [ "$KEEP_WORKDIR" = false ] && [ -d "$WORK_ROOT" ]; then
    rm -rf "$WORK_ROOT"
  fi
}
if [ "$KEEP_WORKDIR" = false ]; then
  trap cleanup EXIT
fi

log() { printf '==> %s\n' "$*"; }

# extract_issue_target_file finds the first lib/*.ts path mentioned in the issue body.
extract_issue_target_file() {
  local body="${1:-}"
  local found
  found="$(printf '%s' "$body" | rg -o 'lib/[A-Za-z0-9_./-]+\.ts' | head -1 || true)"
  if [ -n "$found" ]; then
    printf '%s' "$found"
    return 0
  fi
  printf '%s' "lib/sample-stack.ts"
}

write_kms_edit_script() {
  local edit_sh="${1:?edit_sh}"
  local repo_dir="${2:?repo}"
  local target_file="${3:?target}"
  cat >"$edit_sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd $(printf %q "$repo_dir")
TARGET=$(printf %q "$target_file")
[ -f "\$TARGET" ] || { echo "implement_blocker=target_missing path=\$TARGET"; exit 1; }
if grep -q 'BucketEncryption.KMS' "\$TARGET"; then
  echo "already_kms=true"
  exit 0
fi
sed -i.bak 's/s3\.BucketEncryption\.S3_MANAGED/s3.BucketEncryption.KMS_MANAGED/g' "\$TARGET"
rm -f "\${TARGET}.bak"
grep -n 'encryption' "\$TARGET"
EOF
  chmod +x "$edit_sh"
}

apply_loopback_fixes() {
  local repo_dir="${1:?repo}"
  local cdk_json="${repo_dir}/cdk.json"
  local test_file="${repo_dir}/test/sample-stack.test.ts"

  if [ -f "$cdk_json" ] && jq -e '.context["@aws-cdk/core:enableStackNameDuplicates"]' "$cdk_json" >/dev/null 2>&1; then
    log "loop-back: remove deprecated cdk.json feature flag"
    jq 'del(.context["@aws-cdk/core:enableStackNameDuplicates"])' "$cdk_json" >"${cdk_json}.tmp" \
      && mv "${cdk_json}.tmp" "$cdk_json"
  fi

  if [ -f "$test_file" ] && grep -q "SSEAlgorithm: 'AES256'" "$test_file"; then
    log "loop-back: update test assertion AES256 → aws:kms"
    if sed --version >/dev/null 2>&1; then
      sed -i 's/SSEAlgorithm: '\''AES256'\''/SSEAlgorithm: '\''aws:kms'\''/g' "$test_file"
    else
      sed -i '' "s/SSEAlgorithm: 'AES256'/SSEAlgorithm: 'aws:kms'/g" "$test_file"
    fi
  fi
}

run_validate() {
  bash "${PACK}/stage-runner.sh" validate "$WORK_ROOT" "$REPO" 2>&1 | tee "$WORK_ROOT/validate.out"
}

TARGET_FILE="$(extract_issue_target_file "$ISSUE_BODY")"

log "T2 local run — ${REPO_FULL} issue #${ISSUE_NUM}"
log "pack=${PACK_VERSION} work_root=${WORK_ROOT}"
log "target_file=${TARGET_FILE} (from issue body)"

mkdir -p "$WORK_ROOT"

log "1/4 clone"
bash "${PACK}/clone-pack.sh" clone "$WORK_ROOT" "$CLONE_URL" "$BRANCH" "$ISSUE_NUM" "" "" \
  | tee "$WORK_ROOT/clone.out"

REPO="$(grep -E '^repo_clone_path=' "$WORK_ROOT/clone.out" | tail -1 | cut -d= -f2-)"
if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  echo "FAIL: clone did not produce repo_clone_path" >&2
  exit 1
fi

log "seed workflow notes for commit-pr"
issue_details_json="$(printf '%s' "$PAYLOAD" | jq -c '.issue')"
jq -n \
  --arg rf "$REPO_FULL" \
  --arg in "$ISSUE_NUM" \
  --arg rb "$BRANCH" \
  --arg details "$issue_details_json" \
  '{repository_full_name: $rf, issue_or_pr_number: $in, repository_default_branch: $rb, issue_details: ($details | fromjson)}' \
  >"$WORK_ROOT/notes.json"

run_commit_pr_if_needed() {
  if grep -qE '^pr_url=https?://' "$WORK_ROOT/implement.out" 2>/dev/null; then
    log "PR already opened during implement-app-run"
    grep -E '^(pr_url|working_branch|pr_title)=' "$WORK_ROOT/implement.out" || true
    return 0
  fi
  if [ -z "${GIT_TOKEN:-}" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
    export GIT_TOKEN="$GITHUB_TOKEN"
  fi
  if [ -z "${GIT_TOKEN:-}" ]; then
    log "SKIP commit-pr — export GIT_TOKEN or GITHUB_TOKEN to open a real PR"
    return 0
  fi
  log "commit-pr (draft before validate)"
  bash "${PACK}/stage-runner.sh" commit-pr "$WORK_ROOT" "$REPO_FULL" "$ISSUE_NUM" "" "$BRANCH" \
    | tee "$WORK_ROOT/commit-pr.out"
  if ! grep -qE '^pr_url=https?://' "$WORK_ROOT/commit-pr.out"; then
    echo "FAIL: commit-pr did not return pr_url" >&2
    grep -E '^(pr_error|pr_blocker)=' "$WORK_ROOT/commit-pr.out" >&2 || true
    return 1
  fi
  grep -E '^(pr_url|working_branch|pr_title)=' "$WORK_ROOT/commit-pr.out"
}

log "2/4 implement-app-preflight + edit script"
bash "${PACK}/stage-runner.sh" implement-app-preflight "$REPO" | tee "$WORK_ROOT/preflight.out"
bash "${PACK}/stage-runner.sh" prepare-implement-edits "$WORK_ROOT" "$REPO" | tee "$WORK_ROOT/prepare.out"
EDIT_SH="${WORK_ROOT}/.work/implement-edits.sh"
write_kms_edit_script "$EDIT_SH" "$REPO" "$TARGET_FILE"

log "3/5 implement-app-run"
bash "${PACK}/stage-runner.sh" implement-app-run "$REPO" "$EDIT_SH" "kms_encryption_${TARGET_FILE//\//_}" \
  | tee "$WORK_ROOT/implement.out"

if ! grep -q 'implement_edit_verified=true' "$WORK_ROOT/implement.out"; then
  echo "FAIL: implement stage — no implement_edit_verified=true" >&2
  grep -E 'implement_blocker=' "$WORK_ROOT/implement.out" >&2 || true
  exit 1
fi

run_commit_pr_if_needed || exit 1

log "4/5 validate (pass 1)"
run_validate
if grep -q '^module_quality_summary=PASS' "$WORK_ROOT/validate.out"; then
  log "PASS on first validate"
  grep -E '^(validation_summary|module_quality_summary)=' "$WORK_ROOT/validate.out"
  echo "work_root=${WORK_ROOT}"
  exit 0
fi

log "validate NEEDS_REVISION — loop-back fixes (cdk.json + test)"
apply_loopback_fixes "$REPO"

log "5/5 validate (pass 2 — after loop-back)"
run_validate
grep -E '^(validation_summary|module_quality_summary)=' "$WORK_ROOT/validate.out"

if grep -q '^module_quality_summary=PASS' "$WORK_ROOT/validate.out"; then
  log "PASS after loop-back"
  echo "work_root=${WORK_ROOT}"
  exit 0
fi

echo "FAIL: module_quality_summary not PASS after loop-back" >&2
echo "work_root=${WORK_ROOT}" >&2
exit 1
