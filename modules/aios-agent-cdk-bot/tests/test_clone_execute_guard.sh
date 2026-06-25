#!/usr/bin/env bash
# Smoke test: clone execute_series rejects placeholder URLs and accepts TRIGGER_JSON fallback.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLONE_TMPL="${ROOT}/templates/clone-execute-series-embedded.sh.tftpl"
WORK="$(mktemp -d)"
TRIGGER='{"repository":{"full_name":"stackgenhq/discovery-modules","clone_url":"https://github.com/stackgenhq/discovery-modules.git","default_branch":"main"},"issue":{"number":9}}'

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

if ! grep -q 'is_placeholder_clone_url' "$CLONE_TMPL"; then
  echo "FAIL: clone template missing is_placeholder_clone_url guard" >&2
  exit 1
fi

if ! grep -q 'clone_blocker=placeholder_url' "$CLONE_TMPL"; then
  echo "FAIL: clone template missing placeholder_url blocker" >&2
  exit 1
fi

if ! grep -q 'hydrate_clone_params' "${CLONE_TMPL}"; then
  echo "FAIL: clone template missing hydrate_clone_params" >&2
  exit 1
fi

if ! grep -q 'TRIGGER_JSON_B64' "${CLONE_TMPL}"; then
  echo "FAIL: clone template must support TRIGGER_JSON_B64 fallback" >&2
  exit 1
fi

# Discrete env exports (no inline JSON).
discrete_script="$WORK/discrete-env.sh"
cat >"$discrete_script" <<'EOF'
set -euo pipefail
REPO_CLONE_URL='https://github.com/stackgenhq/discovery-modules.git'
DEFAULT_BRANCH='main'
ISSUE_OR_PR='9'
is_placeholder_clone_url() {
  case "$1" in
    ""|*example.com/example*|*github.com/example/*|*github.com/example.git*) return 0 ;;
  esac
  return 1
}
if is_placeholder_clone_url "${REPO_CLONE_URL:-}"; then exit 1; fi
printf 'ok url=%s issue=%s\n' "$REPO_CLONE_URL" "$ISSUE_OR_PR"
EOF
out="$(bash "$discrete_script")"
printf '%s' "$out" | grep -q 'ok url=https://github.com/stackgenhq/discovery-modules.git'

# TRIGGER_JSON_B64 path (no quotes in JSON on shell command line).
TRIGGER='{"repository":{"full_name":"stackgenhq/discovery-modules","default_branch":"main"},"issue":{"number":9}}'
b64="$(printf '%s' "$TRIGGER" | base64 | tr -d '\n')"
out2="$(bash <<EOF
set -euo pipefail
WORK_ROOT="$(mktemp -d)"
export WORK_ROOT TRIGGER_JSON_B64='$b64'
parse_trigger_json() {
  local raw="\${TRIGGER_JSON:-}"
  [ -n "\$raw" ] || return 1
  REPO_CLONE_URL="\$(printf '%s' "\$raw" | jq -r 'if (.repository.clone_url // "") != "" then .repository.clone_url else "https://github.com/" + .repository.full_name + ".git" end')"
  DEFAULT_BRANCH="\$(printf '%s' "\$raw" | jq -r '.repository.default_branch // "main"')"
  ISSUE_OR_PR="\$(printf '%s' "\$raw" | jq -r '.issue.number // .pull_request.number // empty')"
}
hydrate_clone_params() {
  if [ -n "\${TRIGGER_JSON_B64:-}" ]; then
    TRIGGER_JSON="\$(printf '%s' "\$TRIGGER_JSON_B64" | base64 -d)"
    export TRIGGER_JSON
  fi
  if [ -n "\${REPO_CLONE_URL:-}" ] && [ -n "\${DEFAULT_BRANCH:-}" ] && [ -n "\${ISSUE_OR_PR:-}" ]; then
    return 0
  fi
  parse_trigger_json || true
}
hydrate_clone_params
export REPO_CLONE_URL DEFAULT_BRANCH ISSUE_OR_PR
printf 'url=%s issue=%s\n' "\$REPO_CLONE_URL" "\$ISSUE_OR_PR"
EOF
)"
printf '%s' "$out2" | grep -q 'url=https://github.com/stackgenhq/discovery-modules.git'
printf '%s' "$out2" | grep -q 'issue=9'

block_script="$WORK/block-placeholder.sh"
cat >"$block_script" <<'EOF'
set -euo pipefail
REPO_CLONE_URL='https://github.com/example/example.git'
DEFAULT_BRANCH='main'
ISSUE_OR_PR='1'
is_placeholder_clone_url() {
  case "$1" in
    ""|*example.com/example*|*github.com/example/*|*github.com/example.git*) return 0 ;;
  esac
  return 1
}
if is_placeholder_clone_url "$REPO_CLONE_URL"; then
  echo "clone_blocker=placeholder_url"
  exit 1
fi
EOF
block_out="$(bash "$block_script")" || true
printf '%s' "$block_out" | grep -q 'clone_blocker=placeholder_url'

# Render clone tftpl like Terraform templatefile ($${ -> ${}) and verify bash syntax.
rendered="$(sed 's/\$${/${/g' "$CLONE_TMPL" \
  | sed 's/${shell_work_home}/\/home\/runner/g' \
  | sed 's/${script_pack_version}/test/g')"
rendered="${rendered//\$\{stage_runner_script\}/echo stub stage-runner}"
if ! bash -n <<< "$rendered"; then
  echo "FAIL: rendered clone template has bash syntax errors" >&2
  exit 1
fi
if ! grep -q 'git_clone_url()' <<< "$rendered"; then
  echo "FAIL: rendered clone template must use git_clone_url printf helper" >&2
  exit 1
fi
if grep -qE 'sed.*GIT_(USERNAME|TOKEN)|sed.*x-access-token' <<< "$rendered"; then
  echo "FAIL: clone template must not use sed for auth URL construction" >&2
  exit 1
fi

echo "OK: clone execute guard smoke tests passed"
