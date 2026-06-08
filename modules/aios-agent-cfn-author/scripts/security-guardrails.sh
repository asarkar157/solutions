#!/usr/bin/env bash
# security-guardrails.sh — deterministic Checkov + cfn-nag scan with stable JSON report.
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-/tmp/cfn-author}"
TEMPLATE="${WORK_ROOT}/generated/template.yaml"
REPORT_JSON="${WORK_ROOT}/generated/security-guardrails-report.json"
CHECKOV_JSON="${WORK_ROOT}/generated/checkov-results.json"
CFN_NAG_TXT="${WORK_ROOT}/generated/cfn-nag-results.txt"
CHECKOV_VERSION="${CHECKOV_PIN:-3.2.340}"
CFN_NAG_GEM_VERSION="${CFN_NAG_PIN:-0.8.10}"

mkdir -p "${WORK_ROOT}/generated"

emit_report() {
  local passed="$1"
  local critical="$2"
  local high="$3"
  local blocked="${4:-}"
  python3 - <<PY "${passed}" "${critical}" "${high}" "${blocked}" "${REPORT_JSON}" "${TEMPLATE}" "${CHECKOV_JSON}" "${CFN_NAG_TXT}"
import json, sys, os
from datetime import datetime, timezone

passed, critical, high, blocked = sys.argv[1:5]
report_path, template_path, checkov_path, cfn_nag_path = sys.argv[5:9]

def load_checkov():
    out = {"status": "skipped", "failed_critical": 0, "failed_high": 0, "failed_medium": 0, "failed_low": 0, "findings": []}
    if not os.path.isfile(checkov_path):
        out["reason"] = "checkov_output_missing"
        return out
    try:
        raw = json.load(open(checkov_path))
    except Exception as exc:
        out["status"] = "error"
        out["reason"] = str(exc)
        return out
    rows = raw if isinstance(raw, list) else [raw]
    findings = []
    for block in rows:
        for check in block.get("results", {}).get("failed_checks", []) or []:
            sev = str(check.get("severity", "UNKNOWN")).upper()
            item = {
                "scanner": "checkov",
                "check_id": check.get("check_id", ""),
                "check_name": check.get("check_name", ""),
                "severity": sev,
                "resource": check.get("resource", ""),
                "file_path": check.get("file_path", ""),
                "file_line_range": check.get("file_line_range", []),
            }
            findings.append(item)
            if sev == "CRITICAL":
                out["failed_critical"] += 1
            elif sev == "HIGH":
                out["failed_high"] += 1
            elif sev == "MEDIUM":
                out["failed_medium"] += 1
            elif sev == "LOW":
                out["failed_low"] += 1
    findings.sort(key=lambda x: (x["severity"], x["check_id"], x["resource"]))
    out["findings"] = findings
    out["status"] = "pass" if not findings else "findings"
    return out

def load_cfn_nag():
    out = {"status": "skipped", "fail_count": 0, "findings": []}
    if not os.path.isfile(cfn_nag_path):
        out["reason"] = "cfn_nag_output_missing"
        return out
    findings = []
    for line in open(cfn_nag_path):
        line = line.rstrip("\n")
        if "FAIL" not in line:
            continue
        findings.append({"scanner": "cfn-nag", "line": line})
        out["fail_count"] += 1
    findings.sort(key=lambda x: x["line"])
    out["findings"] = findings
    out["status"] = "pass" if out["fail_count"] == 0 else "findings"
    return out

checkov = load_checkov()
cfn_nag = load_cfn_nag()
critical = int(critical)
high = int(high)
blockers = []
if blocked:
    blockers.append(blocked)
if critical > 0:
    blockers.append("critical_findings")
if high > 0 and os.environ.get("CFN_AUTHOR_BLOCK_HIGH", "false") == "true":
    blockers.append("high_findings")

report = {
    "schema_version": "1",
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "template_path": template_path,
    "scanners": {
        "checkov": checkov,
        "cfn_nag": cfn_nag,
    },
    "summary": {
        "passed": passed == "true" and not blockers,
        "critical_count": critical,
        "high_count": high,
        "blockers": blockers,
    },
}
json.dump(report, open(report_path, "w"), indent=2, sort_keys=True)
print(f"security_guardrails_report_path={report_path}")
PY
}

if [[ ! -f "${TEMPLATE}" ]]; then
  echo "security_guardrails_passed=false"
  echo "policy_scan_passed=false"
  echo "security_guardrails_blocked=missing_generated_template"
  echo "policy_scan_blocked=missing_generated_template"
  emit_report "false" 0 0 "missing_generated_template"
  exit 1
fi

ensure_checkov() {
  if command -v checkov >/dev/null 2>&1; then
    return 0
  fi
  if command -v pip3 >/dev/null 2>&1; then
    pip3 install --user --quiet "checkov==${CHECKOV_VERSION}" >/dev/null 2>&1 || true
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
  command -v checkov >/dev/null 2>&1
}

ensure_cfn_nag() {
  if command -v cfn_nag_scan >/dev/null 2>&1; then
    return 0
  fi
  if command -v gem >/dev/null 2>&1; then
    gem install cfn-nag --version "${CFN_NAG_GEM_VERSION}" --no-document >/dev/null 2>&1 || true
  fi
  command -v cfn_nag_scan >/dev/null 2>&1
}

run_checkov_scan() {
  local counts local_crit local_high
  if checkov -f "${TEMPLATE}" --framework cloudformation --quiet --soft-fail \
    --output json --output-file-path "${CHECKOV_JSON}" >/dev/null 2>&1; then
    checkov_status="pass"
    return 0
  fi
  checkov_status="findings"
  if [[ ! -f "${CHECKOV_JSON}" ]]; then
    return 0
  fi
  counts="$(python3 - <<'PY' "${CHECKOV_JSON}"
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception:
    print("0 0")
    raise SystemExit
crit = high = 0
for result in data if isinstance(data, list) else [data]:
    for check in result.get("results", {}).get("failed_checks", []) or []:
        sev = str(check.get("severity", "")).upper()
        if sev == "CRITICAL":
            crit += 1
        elif sev == "HIGH":
            high += 1
print(crit, high)
PY
)"
  CHECKOV_CRITICAL="$(echo "${counts}" | awk '{print $1}')"
  CHECKOV_HIGH="$(echo "${counts}" | awk '{print $2}')"
}

run_cfn_nag_scan() {
  if cfn_nag_scan -i "${TEMPLATE}" -o txt >"${CFN_NAG_TXT}" 2>/dev/null; then
    cfn_nag_status="pass"
    CFN_NAG_CRITICAL=0
    return 0
  fi
  cfn_nag_status="findings"
  CFN_NAG_CRITICAL="$(grep -c 'FAIL' "${CFN_NAG_TXT}" 2>/dev/null || echo 0)"
}

scan_ran=false
critical=0
high=0
CHECKOV_CRITICAL=0
CHECKOV_HIGH=0
CFN_NAG_CRITICAL=0
checkov_status="skipped_not_installed"
cfn_nag_status="skipped_not_installed"
checkov_pid=""
cfn_nag_pid=""

if ensure_checkov; then
  scan_ran=true
  run_checkov_scan &
  checkov_pid=$!
fi

if ensure_cfn_nag; then
  scan_ran=true
  run_cfn_nag_scan &
  cfn_nag_pid=$!
fi

if [[ -n "${checkov_pid}" ]]; then
  wait "${checkov_pid}"
fi
if [[ -n "${cfn_nag_pid}" ]]; then
  wait "${cfn_nag_pid}"
fi

critical=$((CHECKOV_CRITICAL + CFN_NAG_CRITICAL))
high=${CHECKOV_HIGH}

echo "checkov_status=${checkov_status}"
echo "cfn_nag_status=${cfn_nag_status}"

if [[ "${scan_ran}" == "false" ]]; then
  echo "security_guardrails_passed=false"
  echo "policy_scan_passed=false"
  echo "security_guardrails_blocked=no_scanners_available"
  echo "policy_scan_blocked=no_scanners_available"
  emit_report "false" 0 0 "no_scanners_available"
  exit 1
fi

if [[ "${critical}" -gt 0 ]]; then
  echo "security_guardrails_passed=false"
  echo "policy_scan_passed=false"
  echo "security_guardrails_critical_count=${critical}"
  echo "security_guardrails_high_count=${high}"
  echo "policy_scan_critical_count=${critical}"
  echo "security_guardrails_blocked=critical_findings"
  echo "policy_scan_blocked=critical_findings"
  emit_report "false" "${critical}" "${high}" "critical_findings"
  exit 0
fi

echo "security_guardrails_passed=true"
echo "policy_scan_passed=true"
echo "security_guardrails_critical_count=0"
echo "security_guardrails_high_count=${high}"
echo "policy_scan_critical_count=0"
emit_report "true" 0 "${high}" ""
