#!/usr/bin/env bash
# Smoke test: clone template + clone-pack malformed WORK_ROOT guards.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLONE_TMPL="${ROOT}/templates/clone-execute-series-embedded.sh.tftpl"
CLONE_PACK="${ROOT}/scripts/clone-pack.sh"

if ! grep -q 'normalize_work_root' "$CLONE_TMPL"; then
  echo "FAIL: clone template missing normalize_work_root" >&2
  exit 1
fi

if ! grep -q 'validate_work_root' "$CLONE_TMPL"; then
  echo "FAIL: clone template missing validate_work_root" >&2
  exit 1
fi

if ! grep -q 'validate_work_root' "$CLONE_PACK"; then
  echo "FAIL: clone-pack.sh missing validate_work_root" >&2
  exit 1
fi

STAGE_RUNNER="${ROOT}/scripts/stage-runner.sh"
if ! grep -q 'if \[\[ "\$wr" == \*"\\$HOME"\* \]\]' "$STAGE_RUNNER"; then
  echo "FAIL: stage-runner.sh missing guarded normalize_work_root" >&2
  exit 1
fi

block_out="$(
  bash "$CLONE_PACK" clone \
    '/home/runner/.wf-test//home/runner}' \
    'https://github.com/stackgenhq/discovery-modules.git' \
    main 36884 2>&1
)" || true
printf '%s' "$block_out" | grep -q 'clone_blocker=malformed_work_root'

ok_out="$(
  WORK_ROOT='/home/runner/.wf-test-envonly' \
  REPO_CLONE_URL='https://github.com/example/example.git' \
  DEFAULT_BRANCH='main' \
  ISSUE_OR_PR='1' \
  bash "$CLONE_PACK" clone 2>&1
)" || true
printf '%s' "$ok_out" | grep -q 'clone_blocker=placeholder_url'

# stage-runner normalize must not corrupt absolute /home/runner paths (unguarded ${HOME} replace bug).
stage_norm_out="$(
  bash -c '
    normalize_work_root() {
      local wr="${1:?work_root}"
      if [[ "$wr" == *"\$HOME"* ]]; then wr="${wr//\$HOME/${HOME}}"; fi
      if [[ "$wr" == *"\${HOME}"* ]]; then wr="${wr//\${HOME}/${HOME}}"; fi
      printf "%s" "$wr"
    }
    normalize_work_root "/home/runner/.wf-spec-driven-feature-test"
  '
)"
[ "$stage_norm_out" = "/home/runner/.wf-spec-driven-feature-test" ] || {
  echo "FAIL: normalize_work_root corrupted runner path: got=$stage_norm_out" >&2
  exit 1
}

# Test $HOME/.wf-* normalizes on runner before validate rejects $
home_norm_out="$(
  WORK_ROOT='$HOME/.wf-spec-driven-feature-test' \
  REPO_CLONE_URL='https://github.com/example/example.git' \
  DEFAULT_BRANCH='main' \
  ISSUE_OR_PR='1' \
  HOME='/home/runner' \
  bash "$CLONE_PACK" clone 2>&1
)" || true
printf '%s' "$home_norm_out" | grep -q 'clone_blocker=placeholder_url'

rendered="$(sed 's/\$${/${/g' "$CLONE_TMPL" \
  | sed 's/${shell_work_home}/\/home\/runner/g' \
  | sed 's/${script_pack_version}/20260616.5/g')"
if ! bash -n <<< "$rendered"; then
  echo "FAIL: rendered clone template has bash syntax errors" >&2
  exit 1
fi

echo "OK: spec-symphony clone execute guard tests passed"
