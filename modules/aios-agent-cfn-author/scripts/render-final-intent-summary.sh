#!/usr/bin/env bash
# render-final-intent-summary.sh — deterministic developer summary (no LLM).
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-}"
REQ="${WORK_ROOT}/requirements_spec.json"
PR_URL_FILE="${WORK_ROOT}/pr_url.txt"
SIGNALS="${WORK_ROOT}/final_stage_input.txt"

if [[ -z "${WORK_ROOT}" ]]; then
  echo "summary_error=missing_work_root"
  exit 1
fi

intent=""
stack_name=""
environment=""
confirm_deploy=""
if [[ -f "${REQ}" ]] && command -v jq >/dev/null 2>&1; then
  intent="$(jq -r '.intent // empty' "${REQ}")"
  stack_name="$(jq -r '.stack_name // empty' "${REQ}")"
  environment="$(jq -r '.environment // empty' "${REQ}")"
  confirm_deploy="$(jq -r '.confirm_deploy // empty' "${REQ}")"
fi

pr_url=""
if [[ -f "${PR_URL_FILE}" ]]; then
  pr_url="$(tr -d '[:space:]' < "${PR_URL_FILE}")"
fi

blockers=()
if [[ -f "${SIGNALS}" ]]; then
  while IFS= read -r line; do
    case "${line}" in
      requirements_blocked=true|requirements_blocked:*true*) blockers+=("Requirements incomplete") ;;
      compliance_blocked:*true*|compliance_summary:*FAIL*) blockers+=("Compliance review failed") ;;
      cfn_lint_passed=false|security_guardrails_passed=false|policy_scan_passed=false) blockers+=("Quality checks failed") ;;
      pr_blocker=*|clone_blocker=*|stage_summary:open-pr=blocked*) blockers+=("PR blocked: ${line}") ;;
      governed_deployment_blocked:*true*) blockers+=("Governed deployment gate blocked") ;;
    esac
  done < "${SIGNALS}"
fi

template_path=""
if [[ -f "${WORK_ROOT}/generated/template.yaml" ]]; then
  template_path="${WORK_ROOT}/generated/template.yaml"
fi

if [[ -n "${pr_url}" ]]; then
  cat <<EOF
## Intent-to-infrastructure — complete

**PR:** ${pr_url}

**Stack:** ${stack_name:-not specified} · **Environment:** ${environment:-not specified}

**Intent:** ${intent:-—}

**Template:** \`${template_path:-WORK_ROOT/generated/template.yaml}\`

Validation and security guardrails ran before the PR was opened.
$( [[ "${confirm_deploy}" == "true" ]] && echo "Change-set preview was requested (confirm_deploy=true)." || echo "Change-set preview was skipped (confirm_deploy not true)." )

---
*StackGen cfn-author intent-to-infrastructure workflow.*
EOF
  echo "final_summary_status=success"
  exit 0
fi

if [[ ${#blockers[@]} -gt 0 ]]; then
  cat <<EOF
## Intent-to-infrastructure — blocked

**Intent:** ${intent:-—}

**Blockers:**
$(printf -- '- %s\n' "${blockers[@]}")

Review upstream stage signals and re-run when inputs are corrected.
EOF
  echo "final_summary_status=blocked"
  exit 0
fi

cat <<EOF
## Intent-to-infrastructure — outcome

**Intent:** ${intent:-—}

**Stack:** ${stack_name:-not specified} · **Environment:** ${environment:-not specified}

No PR URL was recorded. Check open-pr and quality stage outputs for \`pr_blocker=\` or \`stage_summary:open-pr=blocked\`.
EOF
echo "final_summary_status=unknown"
