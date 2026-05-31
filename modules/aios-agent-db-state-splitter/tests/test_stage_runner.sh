#!/usr/bin/env bash
# Smoke tests for stage-runner script-pack guards.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${ROOT}/scripts/stage-runner.sh"
PY="${ROOT}/scripts/allocate_manifest.py"
WORK="$(mktemp -d)"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# Direct repo checkout invocation (developer / CI) — sibling has canonical allocate_manifest.py.
out="$(bash "$RUNNER" preflight "$WORK")"
printf '%s' "$out" | grep -q 'preflight_ok=true'

# Unembedded stdin without allocate_manifest.py in WORK_ROOT must fail.
if bash -s preflight "$WORK" 2>/dev/null << EOF
$(cat "$RUNNER")
EOF
then
  echo "FAIL: unembedded bash -s without allocate py should fail" >&2
  exit 1
fi

# Embedded invocation with verified allocate manifest succeeds.
export DBSPLIT_EMBEDDED=1
export DBSPLIT_ALLOCATE_SHA256
DBSPLIT_ALLOCATE_SHA256="$(sha256sum "$PY" | awk '{print $1}')"
mkdir -p "$WORK/scripts"
cp "$PY" "$WORK/scripts/allocate_manifest.py"
out_embed="$(bash -s preflight "$WORK" << EOF
$(cat "$RUNNER")
EOF
)"
printf '%s' "$out_embed" | grep -q 'script_pack_version='

echo "OK: stage-runner script-pack smoke tests passed"
