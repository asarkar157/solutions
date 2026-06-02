#!/usr/bin/env bash
# Static validation for the module using OpenTofu without contacting remote providers.
# This exists because `tofu test` can create real infrastructure; this script is safe to run locally and in CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v tofu >/dev/null 2>&1; then
  echo "SKIP: tofu_static_validate_test requires OpenTofu (tofu) in PATH" >&2
  exit 0
fi

tofu fmt -check -recursive >/dev/null
tofu init -backend=false -input=false >/dev/null 2>&1 || true
tofu validate >/dev/null

# Ensure tarball embedding path is wired and we don't reference runtime git fetch anymore.
if grep -q 'monosplit-fetch-script-pack.sh.tftpl' main.tf; then
  echo "FAIL: main.tf must not reference monosplit-fetch-script-pack.sh.tftpl (runtime tooling repo fetch removed)" >&2
  exit 1
fi
if ! grep -q 'archive_file" "monosplit_script_pack' main.tf; then
  echo "FAIL: main.tf must define archive_file.monosplit_script_pack" >&2
  exit 1
fi
if ! grep -q 'MONOSPLIT_SCRIPT_PACK_TARBALL_B64' main.tf; then
  echo "FAIL: ubuntu integration env_vars must set MONOSPLIT_SCRIPT_PACK_TARBALL_B64" >&2
  exit 1
fi
if grep -q 'recycle_ubuntu_sidecar' templates/monosplit-install-script-pack.sh.tftpl 2>/dev/null; then
  echo "FAIL: install template must not tell operators to recycle sidecars" >&2
  exit 1
fi

# Quick sanity: decode commands should stay paste-sized.
WF="wf-tofu-static-validate-test"
MAX_LEN=600
for expr in \
  local.monosplit_scan_execute_series_decode_command \
  local.monosplit_guidance_pr_execute_series_decode_command \
  local.monosplit_scaffold_execute_series_decode_command \
  local.monosplit_extract_pr_execute_series_decode_command
do
  cmd="$(tofu console -input=false <<< "replace(${expr}, \"{{workflow_run_id}}\", \"${WF}\")" | tr -d '\r')"
  # tofu console prints raw strings sometimes with surrounding quotes; normalize.
  cmd="${cmd%\"}"; cmd="${cmd#\"}"
  if [ "${#cmd}" -gt "${MAX_LEN}" ]; then
    echo "FAIL: ${expr} too long (${#cmd} > ${MAX_LEN})" >&2
    exit 1
  fi
done

# Tarball bytes must match stage-runner on disk (catches stale fixed-path archives).
tofu apply -auto-approve -input=false -target=data.archive_file.monosplit_script_pack \
  -var='model_names=["test"]' \
  -var='policy_ids={dangerous_ops="00000000-0000-0000-0000-000000000099"}' \
  >/dev/null
python3 - <<'PY'
import hashlib, pathlib, re, subprocess, tarfile

root = pathlib.Path(".")
runner = (root / "scripts/stage-runner.sh").read_bytes()
want = hashlib.sha256(runner).hexdigest()
main = (root / "main.tf").read_text()
if "monosplit-script-pack-${sha256(file(" not in main and "monosplit-script-pack-${sha256(file(\"" not in main:
    raise SystemExit("FAIL: archive output_path must include stage-runner sha256 suffix")
tar_path = root / ".generated" / f"monosplit-script-pack-{want}.tar.gz"
if not tar_path.is_file():
    raise SystemExit(f"FAIL: expected tarball missing: {tar_path}")
with tarfile.open(tar_path) as tf:
    got = hashlib.sha256(tf.extractfile("stage-runner.sh").read()).hexdigest()
if got != want:
    raise SystemExit(f"FAIL: tarball stage-runner sha {got} != disk {want}")
PY

echo "OK: tofu static validation passed"
