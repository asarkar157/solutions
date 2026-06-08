#!/usr/bin/env bash
# stage-runner.sh — dispatch validate-template, commit-pr, reconcile-pr subcommands.
set -euo pipefail

CMD="${1:-}"
WORK_ROOT="${WORK_ROOT:-/tmp/cfn-author}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${CMD}" in
  security-guardrails|policy-scan)
    TEMPLATE="${WORK_ROOT}/generated/template.yaml"
    if [[ ! -f "${TEMPLATE}" ]]; then
      echo "security_guardrails_passed=false"
      echo "policy_scan_passed=false"
      echo "security_guardrails_blocked=missing_generated_template"
      echo "policy_scan_blocked=missing_generated_template"
      exit 1
    fi
    bash "${SCRIPT_DIR}/security-guardrails.sh"
    ;;
  validate-template)
    TEMPLATE="${WORK_ROOT}/generated/template.yaml"
    if [[ ! -f "${TEMPLATE}" ]]; then
      echo "validate_blocked=missing_generated_template"
      exit 1
    fi
    bash "${SCRIPT_DIR}/cfn-preview.sh" "${TEMPLATE}"
    ;;
  quality-check)
    TEMPLATE="${WORK_ROOT}/generated/template.yaml"
    if [[ ! -f "${TEMPLATE}" ]]; then
      echo "validate_blocked=missing_generated_template"
      echo "security_guardrails_blocked=missing_generated_template"
      exit 1
    fi
    lint_out="$(bash "${SCRIPT_DIR}/cfn-preview.sh" "${TEMPLATE}" 2>&1)" || true
    printf '%s\n' "${lint_out}"
    if printf '%s\n' "${lint_out}" | grep -qE 'cfn_lint_passed=false|validate_blocked='; then
      exit 0
    fi
    if [[ "${CFN_AUTHOR_SKIP_GUARDRAILS:-0}" == "1" ]]; then
      echo "security_guardrails_passed=skipped_disabled"
      echo "policy_scan_passed=skipped_disabled"
      exit 0
    fi
    bash "${SCRIPT_DIR}/security-guardrails.sh"
    ;;
  parse-requirements)
    export WORKSPACE_ID="${WORKSPACE_ID:-${CFN_AUTHOR_DEFAULT_WORKSPACE:-}}"
    bash "${SCRIPT_DIR}/parse-requirements.sh"
    ;;
  parse-intent-once)
    export WORKSPACE_ID="${WORKSPACE_ID:-${CFN_AUTHOR_DEFAULT_WORKSPACE:-}}"
    if [[ -z "${WORK_ROOT}" ]]; then
      echo "requirements_blocked=true"
      echo "requirements_parsed=false"
      echo "requirements_blocker=missing_work_root"
      exit 1
    fi
    mkdir -p "${WORK_ROOT}"
    cat > "${WORK_ROOT}/stage_input.raw"
    export STAGE_INPUT_FILE="${WORK_ROOT}/stage_input.raw"
    bash "${SCRIPT_DIR}/parse-requirements.sh"
    ;;
  render-final-summary)
    bash "${SCRIPT_DIR}/render-final-intent-summary.sh"
    ;;
  architecture-lint)
    export FEDRAMP_PROFILE="${FEDRAMP_PROFILE:-${CFN_AUTHOR_FEDRAMP_PROFILE:-moderate}}"
    export CFN_AUTHOR_HIGH_RPS_THRESHOLD="${CFN_AUTHOR_HIGH_RPS_THRESHOLD:-100000}"
    bash "${SCRIPT_DIR}/architecture-lint.sh"
    ;;
  compliance-check)
    export FEDRAMP_PROFILE="${FEDRAMP_PROFILE:-${CFN_AUTHOR_FEDRAMP_PROFILE:-moderate}}"
    bash "${SCRIPT_DIR}/compliance-check.sh"
    ;;
  catalog-discover)
    export CATALOG_REPO="${CATALOG_REPO:-}"
    export CFN_AUTHOR_CATALOG_PATH="${CFN_AUTHOR_CATALOG_PATH:-${CFN_AUTHOR_TEMPLATE_PREFIX:-cloudformation/catalog/}}"
    bash "${SCRIPT_DIR}/catalog-discover.sh"
    ;;
  change-set-preview)
    export AWS_REGION="${AWS_REGION:-us-east-1}"
    bash "${SCRIPT_DIR}/change-set-preview.sh"
    ;;
  commit-pr)
    TEMPLATE="${WORK_ROOT}/generated/template.yaml"
    export TEMPLATE_BODY_FILE="${TEMPLATE}"
    export REPO_FULL_NAME="${REPO_FULL_NAME:-${CFN_AUTHOR_DEFAULT_REPO:-}}"
    export BASE_BRANCH="${BASE_BRANCH:-${CFN_AUTHOR_DEFAULT_BRANCH:-main}}"
    export TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-${CFN_AUTHOR_TEMPLATE_PREFIX:-cloudformation/}}"
    export TEMPLATE_FILE="${TEMPLATE_FILE:-template.yaml}"
    export PR_TITLE="${PR_TITLE:-}"
    # PR body is always rendered by commit-and-pr.sh (never from LLM-exported PR_BODY).
    export PR_BODY=""
    export STACK_NAME="${STACK_NAME:-}"
    export ENVIRONMENT="${ENVIRONMENT:-}"
    export INTENT="${INTENT:-}"
    export AWS_REGION="${AWS_REGION:-}"
    bash "${SCRIPT_DIR}/commit-and-pr.sh" "${WORK_ROOT}" "${REPO_FULL_NAME}"
    ;;
  reconcile-pr)
    export REPO_FULL_NAME="${REPO_FULL_NAME:-}"
    export BASE_BRANCH="${BASE_BRANCH:-main}"
    export PR_TITLE="${PR_TITLE:-fix(cfn): incorporate drift into desired state}"
    export PR_BODY=""
    TEMPLATE="${WORK_ROOT}/reconcile/template.yaml"
    export TEMPLATE_BODY_FILE="${TEMPLATE}"
    commit_out="$(bash "${SCRIPT_DIR}/commit-and-pr.sh" "${WORK_ROOT}" "${REPO_FULL_NAME}")"
    printf '%s\n' "${commit_out}"
    printf '%s\n' "${commit_out}" | grep -E '^pr_url=' | sed 's/^pr_url=/reconcile_pr_url=/'
    ;;
  *)
    echo "script_pack_error=unknown_command"
    exit 1
    ;;
esac
