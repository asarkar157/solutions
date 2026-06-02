#!/usr/bin/env bash
# Ensures install_script_pack does not cp scripts onto themselves when stage-runner
# runs from WORK_ROOT/scripts after tarball bootstrap (embedded execute_series path).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

scripts_dir="${WORK}/scripts"
mkdir -p "${scripts_dir}"
cp "${ROOT}/scripts/"*.sh "${scripts_dir}/"
chmod +x "${scripts_dir}/"*.sh

out="$(MONOREPO_SPLIT_EMBEDDED=1 bash "${scripts_dir}/stage-runner.sh" clone-and-scan \
  "${WORK}" "https://example.invalid/repo.git" main wf-install-test 2>&1)" || true

if echo "$out" | grep -q "are the same file"; then
  echo "FAIL: install_script_pack attempted cp onto itself:" >&2
  echo "$out" >&2
  exit 1
fi

if ! echo "$out" | grep -qE 'script_pack_install=reused_work_root_scripts|script_pack_version='; then
  echo "FAIL: expected script pack reuse marker in output:" >&2
  echo "$out" >&2
  exit 1
fi

if [ ! -f "${scripts_dir}/.script_pack_version" ]; then
  echo "FAIL: .script_pack_version not written under WORK_ROOT/scripts" >&2
  exit 1
fi

echo "OK: stage-runner install_script_pack reuses WORK_ROOT/scripts without same-file cp"
