#!/usr/bin/env bash
# compliance-check_test.sh — smoke test deterministic compliance rules.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(mktemp -d)"
trap 'rm -rf "${WORK_ROOT}"' EXIT

mkdir -p "${WORK_ROOT}/generated"
printf '{"intent":"public s3 bucket open to internet in production","environment":"production","stack_name":"bad"}' \
  > "${WORK_ROOT}/requirements_spec.json"

export WORK_ROOT
out="$(bash "${ROOT}/compliance-check.sh")"
printf '%s\n' "${out}"

echo "${out}" | grep -q 'compliance_summary=FAIL' || { echo "FAIL: expected FAIL" >&2; exit 1; }
echo "${out}" | grep -q 'compliance_blocked=true' || { echo "FAIL: expected blocked" >&2; exit 1; }
jq -e '.compliance_summary == "FAIL"' "${WORK_ROOT}/generated/compliance_report.json" >/dev/null

printf '{"intent":"private RDS in staging","environment":"staging","stack_name":"ok"}' \
  > "${WORK_ROOT}/requirements_spec.json"
out="$(bash "${ROOT}/compliance-check.sh")"
echo "${out}" | grep -q 'compliance_summary=PASS' || { echo "FAIL: expected PASS for benign intent" >&2; exit 1; }

echo "OK: compliance-check rules"
