#!/usr/bin/env bash
# compliance-check.sh — deterministic FedRAMP + org baseline preflight on requirements_spec.json.
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="${WORK_ROOT}/requirements_spec.json"
OUT="${WORK_ROOT}/generated/compliance_report.json"
FEDRAMP_RULES="${CFN_AUTHOR_FEDRAMP_RULES:-${SCRIPT_DIR}/compliance-rules/fedramp-moderate.json}"
BASELINE_RULES="${CFN_AUTHOR_BASELINE_RULES:-${SCRIPT_DIR}/compliance-rules/org-baseline.json}"

if [[ -z "${WORK_ROOT}" ]]; then
  echo "compliance_summary=FAIL"
  echo "compliance_blocked=true"
  exit 0
fi

mkdir -p "${WORK_ROOT}/generated"

if [[ ! -f "${SPEC}" ]]; then
  echo "compliance_summary=FAIL"
  echo "compliance_blocked=true"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "compliance_summary=FAIL"
  echo "compliance_blocked=true"
  exit 0
fi

intent="$(jq -r '.intent // ""' "${SPEC}")"
environment="$(jq -r '.environment // ""' "${SPEC}" | tr '[:upper:]' '[:lower:]')"
workspace_id="$(jq -r '.workspace_id // ""' "${SPEC}")"
correlation_id="$(jq -r '.correlation_id // ""' "${SPEC}")"
intent_lc="$(printf '%s' "${intent}" | tr '[:upper:]' '[:lower:]')"

fedramp_findings=()
baseline_findings=()
critical=0

evaluate_rules() {
  local rules_file="$1"
  local -n findings_ref=$2
  [[ -f "${rules_file}" ]] || return 0
  while IFS= read -r rule; do
    [[ -n "${rule}" ]] || continue
    local id severity message hint env_filter matched pattern
    id="$(echo "${rule}" | jq -r '.id')"
    severity="$(echo "${rule}" | jq -r '.severity')"
    message="$(echo "${rule}" | jq -r '.message')"
    hint="$(echo "${rule}" | jq -r '.remediation_hint // ""')"
    env_filter="$(echo "${rule}" | jq -r '.environment // [] | join("|")')"
    if [[ -n "${env_filter}" && -n "${environment}" ]]; then
      if ! printf '%s' "${environment}" | grep -qiE "${env_filter}"; then
        continue
      fi
    fi
    matched=false
    while IFS= read -r pattern; do
      [[ -n "${pattern}" ]] || continue
      if printf '%s' "${intent_lc}" | grep -qiE "${pattern}"; then
        matched=true
        break
      fi
    done < <(echo "${rule}" | jq -r '.intent_patterns[]?')
    if [[ "${matched}" != "true" ]]; then
      continue
    fi
    findings_ref+=("$(jq -nc --arg id "${id}" --arg sev "${severity}" --arg msg "${message}" --arg hint "${hint}" \
      '{control_id: $id, severity: $sev, message: $msg, remediation_hint: $hint}')")
    if [[ "${severity}" == "critical" ]]; then
      critical=$((critical + 1))
    fi
  done < <(jq -c '.rules[]?' "${rules_file}" 2>/dev/null || true)
}

evaluate_rules "${FEDRAMP_RULES}" fedramp_findings
evaluate_rules "${BASELINE_RULES}" baseline_findings

summary="PASS"
blocked="false"
if [[ "${critical}" -gt 0 ]]; then
  summary="FAIL"
  blocked="true"
elif [[ $((${#fedramp_findings[@]} + ${#baseline_findings[@]})) -gt 0 ]]; then
  summary="NEEDS_REVIEW"
fi

jq -nc \
  --arg summary "${summary}" \
  --arg blocked "${blocked}" \
  --arg workspace_id "${workspace_id}" \
  --arg correlation_id "${correlation_id}" \
  --argjson fedramp "$(if [[ ${#fedramp_findings[@]} -eq 0 ]]; then echo '[]'; else printf '%s\n' "${fedramp_findings[@]}" | jq -s '.'; fi)" \
  --argjson baseline "$(if [[ ${#baseline_findings[@]} -eq 0 ]]; then echo '[]'; else printf '%s\n' "${baseline_findings[@]}" | jq -s '.'; fi)" \
  '{
    compliance_summary: $summary,
    compliance_blocked: $blocked,
    fedramp_findings: $fedramp,
    baseline_findings: $baseline
  }
  + (if ($workspace_id | length) > 0 then {workspace_id: $workspace_id} else {} end)
  + (if ($correlation_id | length) > 0 then {correlation_id: $correlation_id} else {} end)' \
  > "${OUT}"

echo "compliance_summary=${summary}"
echo "compliance_blocked=${blocked}"
echo "compliance_report_path=${OUT}"
