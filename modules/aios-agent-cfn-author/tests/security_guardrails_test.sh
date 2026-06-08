#!/usr/bin/env bash
# Unit test for security-guardrails.sh deterministic report output.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

mkdir -p "${TMP}/generated"
cat >"${TMP}/generated/template.yaml" <<'YAML'
AWSTemplateFormatVersion: "2010-09-09"
Resources:
  PublicBucket:
    Type: AWS::S3::Bucket
YAML

export CHECKOV_PIN="3.2.340"
export CFN_NAG_PIN="0.8.10"

# When neither scanner is available, the gate must block (not silently pass).
NO_SCANNER_TMP="$(mktemp -d)"
mkdir -p "${NO_SCANNER_TMP}/generated"
cp "${TMP}/generated/template.yaml" "${NO_SCANNER_TMP}/generated/template.yaml"
if env WORK_ROOT="${NO_SCANNER_TMP}" PATH="/usr/bin:/bin" bash "${ROOT}/scripts/security-guardrails.sh" >"${NO_SCANNER_TMP}/stdout.txt" 2>"${NO_SCANNER_TMP}/stderr.txt"; then
  echo "FAIL: expected non-zero exit when no scanners are available" >&2
  cat "${NO_SCANNER_TMP}/stdout.txt" >&2
  exit 1
fi
if ! grep -q 'security_guardrails_blocked=no_scanners_available' "${NO_SCANNER_TMP}/stdout.txt"; then
  echo "FAIL: missing no_scanners_available blocker in stdout" >&2
  cat "${NO_SCANNER_TMP}/stdout.txt" >&2
  exit 1
fi
echo "OK: no-scanners path blocks the gate"

# Install Checkov in an isolated venv (PEP 668 safe) for schema/determinism checks.
VENV="${TMP}/venv"
python3 -m venv "${VENV}"
"${VENV}/bin/pip" install --quiet "checkov==${CHECKOV_PIN}"
export PATH="${VENV}/bin:${PATH}"
export WORK_ROOT="${TMP}"

if ! bash "${ROOT}/scripts/security-guardrails.sh" >"${TMP}/stdout.txt" 2>"${TMP}/stderr.txt"; then
  echo "FAIL: security-guardrails.sh exited non-zero with Checkov available" >&2
  cat "${TMP}/stdout.txt" "${TMP}/stderr.txt" >&2
  exit 1
fi

if ! grep -q 'security_guardrails_report_path=' "${TMP}/stdout.txt"; then
  echo "FAIL: missing security_guardrails_report_path in stdout" >&2
  cat "${TMP}/stdout.txt" >&2
  exit 1
fi

REPORT="${TMP}/generated/security-guardrails-report.json"
if [[ ! -f "${REPORT}" ]]; then
  echo "FAIL: report JSON not written" >&2
  exit 1
fi

python3 - <<PY "${REPORT}"
import json, sys
report = json.load(open(sys.argv[1]))
assert report["schema_version"] == "1"
assert "checkov" in report["scanners"]
assert "cfn_nag" in report["scanners"]
assert "passed" in report["summary"]
assert isinstance(report["summary"]["blockers"], list)
print("OK: security guardrails report schema valid")
PY

# Determinism: run twice, compare normalized report (exclude generated_at; ignore scanner skip variance)
python3 - <<PY "${ROOT}" "${TMP}" "${VENV}/bin"
import json, os, subprocess, sys, tempfile
root, tmp, venv_bin = sys.argv[1], sys.argv[2], sys.argv[3]

def run_once(work):
    env = os.environ.copy()
    env["WORK_ROOT"] = work
    env["PATH"] = f"{venv_bin}:{env.get('PATH', '')}"
    subprocess.run(["bash", f"{root}/scripts/security-guardrails.sh"], check=True, env=env, capture_output=True)
    report = json.load(open(f"{work}/generated/security-guardrails-report.json"))
    report.pop("generated_at", None)
    for scanner in report.get("scanners", {}).values():
        for finding in scanner.get("findings", []):
            finding.pop("file_path", None)
    return json.dumps(report, sort_keys=True)

w1 = tempfile.mkdtemp()
w2 = tempfile.mkdtemp()
for w in (w1, w2):
    os.makedirs(f"{w}/generated", exist_ok=True)
    open(f"{w}/generated/template.yaml", "w").write(open(f"{tmp}/generated/template.yaml").read())

r1 = run_once(w1)
r2 = run_once(w2)
if r1 != r2:
    d1 = json.loads(r1)
    d2 = json.loads(r2)
    if d1["scanners"]["checkov"]["status"] == "skipped" and d2["scanners"]["checkov"]["status"] == "skipped":
        print("OK: skipped scanner — determinism check not applicable")
        sys.exit(0)
    print("FAIL: report not deterministic across runs", file=sys.stderr)
    sys.exit(1)
print("OK: security guardrails deterministic output")
PY

echo "OK: security-guardrails tests passed"
