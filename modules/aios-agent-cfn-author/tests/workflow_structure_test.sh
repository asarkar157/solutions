#!/usr/bin/env bash
# Static structure checks for aios-agent-cfn-author workflows.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"
GOV="${ROOT}/governance_workflows.tf"
SPAWN="${ROOT}/spawn_contracts.tf"
SCRIPT_PACK="${ROOT}/script_pack.tf"

intent_stages=(
  parse-intent
  intent-blocked-gate
  compliance-check
  compliance-blocked-gate
  synthesize-template
  quality-check
  quality-rework-loop
  quality-blocked-gate
  architecture-fit-review
  architecture-blocked-gate
  open-pr
  publish-blocked-gate
  preview-disabled-gate
  preview-skip-gate
  preview-safety-gate
  preview-changes
  final-intent-summary
)

drift_stages=(
  normalize-drift-ingress
  parse-drift-scope
  scope-blocked-gate
  inventory-stacks
  inventory-empty-gate
  parallel-detect-drift
  parallel-fan-in-gate
  drift-retry-loop
  synthesize-drift-report
  classify-drift-recommendation
  no-drift-skip-gate
  reconcile-template-diff
  reconcile-pr-skip-gate
  open-reconcile-pr
  final-drift-summary
)

for stage in "${intent_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing intent stage ${stage}" >&2
    exit 1
  fi
done

for stage in "${drift_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing drift stage ${stage}" >&2
    exit 1
  fi
done

if ! grep -q 'resource "sg_workflow" "intent_to_infrastructure"' "${MAIN}"; then
  echo "FAIL: missing intent_to_infrastructure workflow" >&2
  exit 1
fi

if ! grep -q 'resource "sg_workflow" "cloudformation_drift_management"' "${MAIN}"; then
  echo "FAIL: missing cloudformation_drift_management workflow" >&2
  exit 1
fi

if ! grep -q 'resource "sg_workflow" "contextual_compliance"' "${GOV}"; then
  echo "FAIL: missing contextual_compliance workflow" >&2
  exit 1
fi

if ! grep -q 'resource "sg_workflow" "governed_deployment"' "${GOV}"; then
  echo "FAIL: missing governed_deployment workflow" >&2
  exit 1
fi

if ! grep -q 'module "governance_runbooks"' "${MAIN}"; then
  echo "FAIL: must nest aios-cfn-governance-runbooks module" >&2
  exit 1
fi

if ! grep -q 'continuous_governance' "${MAIN}"; then
  echo "FAIL: drift workflow must reference continuous governance runbook" >&2
  exit 1
fi

for agent in cfn-author cfn-drift-manager; do
  if ! grep -q "personas/${agent}.md" "${MAIN}"; then
    echo "FAIL: missing persona ${agent}" >&2
    exit 1
  fi
done

if ! grep -q 'action_type[[:space:]]*=[[:space:]]*"loop_stage"' "${MAIN}"; then
  echo "FAIL: must define loop_stage gates" >&2
  exit 1
fi

if ! grep -q 'action_type[[:space:]]*=[[:space:]]*"conditional_skip"' "${MAIN}"; then
  echo "FAIL: must define conditional_skip gates" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_drift_batches' "${MAIN}"; then
  echo "FAIL: parallel-detect-drift must set spawn_contracts" >&2
  exit 1
fi

if ! grep -q 'drift-detect-runner-batch-' "${SPAWN}"; then
  echo "FAIL: spawn_contracts must register drift batch runners" >&2
  exit 1
fi

if ! grep -q 'expected_bedrock_model_name' "${ROOT}/variables.tf"; then
  echo "FAIL: Bedrock-only model_names validation required" >&2
  exit 1
fi

if ! grep -q 'classify-drift-recommendation' "${MAIN}"; then
  echo "FAIL: drift workflow must classify recommendations" >&2
  exit 1
fi

if ! grep -q 'resource "sg_webhook" "intent_to_infrastructure"' "${MAIN}"; then
  echo "FAIL: intent-to-infrastructure webhook must be defined" >&2
  exit 1
fi

if ! grep -q 'source = "webhook"' "${MAIN}"; then
  echo "FAIL: intent workflow must include active webhook trigger" >&2
  exit 1
fi

if ! grep -q 'resource "sg_runbook_sop" "normalize_drift_ingress"' "${MAIN}"; then
  echo "FAIL: normalize-drift-ingress runbook must be defined" >&2
  exit 1
fi

if grep -A5 'resource "sg_runbook_sop" "normalize_drift_ingress"' "${MAIN}" | grep -q 'content\s*='; then
  echo "FAIL: normalize_drift_ingress must use description, not content" >&2
  exit 1
fi

if ! grep -q 'compliance_webhook_ingress_payload_url' "${ROOT}/outputs.tf"; then
  echo "FAIL: compliance_webhook_ingress_payload_url output must be defined" >&2
  exit 1
fi

if ! grep -q 'enable_drift_webhook' "${ROOT}/variables.tf"; then
  echo "FAIL: drift webhook variable must be defined" >&2
  exit 1
fi

if ! grep -q 'resource "sg_webhook" "drift_management"' "${MAIN}"; then
  echo "FAIL: drift webhook resource must be defined" >&2
  exit 1
fi

if ! grep -q 'variable "workspace"' "${ROOT}/variables.tf"; then
  echo "FAIL: workspace variable must be defined" >&2
  exit 1
fi

if ! grep -q 'resource "sg_runbook_sop" "security_guardrails"' "${MAIN}"; then
  echo "FAIL: security-guardrails runbook must be defined" >&2
  exit 1
fi

if ! grep -q 'quality-check' "${MAIN}"; then
  echo "FAIL: intent workflow must include quality-check stage" >&2
  exit 1
fi

if ! grep -q 'enable_security_guardrails_gate' "${ROOT}/variables.tf"; then
  echo "FAIL: enable_security_guardrails_gate variable must be defined" >&2
  exit 1
fi

if ! grep -q 'archive_file" "cfn_author_script_pack' "${SCRIPT_PACK}"; then
  echo "FAIL: script_pack.tf must define archive_file.cfn_author_script_pack" >&2
  exit 1
fi

if grep -A12 'spawn_contract_open_pr' "${SPAWN}" | grep -q 'github_tool_prefix'; then
  echo "FAIL: open-pr spawn must use Ubuntu gh only (no github-integration execute_series)" >&2
  exit 1
fi

if ! grep -q 'spawn_contract_quality_check' "${SPAWN}"; then
  echo "FAIL: spawn_contracts must register quality-check-runner" >&2
  exit 1
fi

if ! grep -q 'requirements_blocked=true' "${MAIN}"; then
  echo "FAIL: intent-blocked-gate must match structured requirements_blocked note" >&2
  exit 1
fi

if ! grep -q 'spawn_contract_parse_requirements' "${SPAWN}"; then
  echo "FAIL: spawn_contracts must register parse-requirements-runner" >&2
  exit 1
fi

if ! grep -q 'spawn_contract_final_intent_summary' "${SPAWN}"; then
  echo "FAIL: spawn_contracts must register final-intent-summary-runner" >&2
  exit 1
fi

if grep -A8 'spawn_contract_open_pr = {' "${SPAWN}" | grep -qE 'REPO_FULL_NAME PR_BODY|export PR_BODY'; then
  echo "FAIL: open-pr spawn must not export PR_BODY (script renders body)" >&2
  exit 1
fi

if grep -q 'if \[\[ -z "\${PR_BODY}" \]\]' "${ROOT}/scripts/commit-and-pr.sh"; then
  echo "FAIL: commit-and-pr.sh must always render PR body (no empty PR_BODY branch)" >&2
  exit 1
fi

if ! grep -q 'unset PR_BODY' "${ROOT}/scripts/commit-and-pr.sh"; then
  echo "FAIL: commit-and-pr.sh must unset PR_BODY before rendering" >&2
  exit 1
fi

if ! grep -q 'export PR_BODY=""' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner commit-pr must clear PR_BODY before commit-and-pr.sh" >&2
  exit 1
fi

if ! grep -qE 'planner_max_tool_iterations[[:space:]]*=[[:space:]]*"10"' "${MAIN}"; then
  echo "FAIL: intent workflow planner_max_tool_iterations must be 10" >&2
  exit 1
fi

if ! grep -q 'halguard_skip_subagent_task_types' "${MAIN}"; then
  echo "FAIL: intent workflow metadata must include halguard_skip_subagent_task_types" >&2
  exit 1
fi

if ! grep -q 'terminal_calling_halguard_mode' "${MAIN}"; then
  echo "FAIL: intent workflow metadata must include terminal_calling_halguard_mode" >&2
  exit 1
fi

if ! grep -q 'runner_terminal_tools' "${SPAWN}"; then
  echo "FAIL: spawn_contracts must define runner_terminal_tools without read_notes" >&2
  exit 1
fi

if ! grep -q 'parse-intent-once' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must support parse-intent-once for single-shot parse" >&2
  exit 1
fi

if grep -q 'cfn-company-best-practices' "${MAIN}" && grep -q 'skill_refs.*cfn-company-best-practices' "${MAIN}"; then
  echo "FAIL: synthesize-template must not load_skill cfn-company-best-practices (embedded in runbook)" >&2
  exit 1
fi

if ! grep -q 'enable_change_set_preview' "${ROOT}/variables.tf"; then
  echo "FAIL: enable_change_set_preview variable must be defined" >&2
  exit 1
fi

if ! grep -q 'preview-disabled-gate' "${MAIN}"; then
  echo "FAIL: intent workflow must include preview-disabled-gate" >&2
  exit 1
fi

if ! grep -q 'spawn_contract_compliance_check' "${SPAWN}"; then
  echo "FAIL: spawn_contracts must register compliance-check-runner" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_intent_compliance_check' "${MAIN}"; then
  echo "FAIL: compliance-check must set spawn_contracts" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/scripts/compliance-check.sh" ]]; then
  echo "FAIL: compliance-check.sh script must exist" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/scripts/catalog-discover.sh" ]]; then
  echo "FAIL: catalog-discover.sh script must exist" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/scripts/change-set-preview.sh" ]]; then
  echo "FAIL: change-set-preview.sh script must exist" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/scripts/governed-deployment-check.sh" ]]; then
  echo "FAIL: governed-deployment-check.sh script must exist" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/scripts/parse-requirements.sh" ]]; then
  echo "FAIL: parse-requirements.sh script must exist" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/scripts/render-final-intent-summary.sh" ]]; then
  echo "FAIL: render-final-intent-summary.sh script must exist" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_intent_parse_requirements' "${MAIN}"; then
  echo "FAIL: parse-intent must set spawn_contracts" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_intent_final_summary' "${MAIN}"; then
  echo "FAIL: final-intent-summary must set spawn_contracts" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_intent_preview_changes' "${SPAWN}"; then
  echo "FAIL: spawn_contracts must register preview-changes-runner" >&2
  exit 1
fi

preview_tools_block="$(sed -n '/spawn_contract_preview_changes = {/,/^  }/p' "${SPAWN}")"
if echo "${preview_tools_block}" | grep -q 'preview_aws_tools'; then
  echo "FAIL: preview-changes spawn must use Ubuntu shell (change-set-preview.sh), not AWS MCP" >&2
  exit 1
fi
if ! echo "${preview_tools_block}" | grep -q 'preview_shell_tools'; then
  echo "FAIL: preview-changes spawn must set tool_names to preview_shell_tools" >&2
  exit 1
fi

if ! grep -q 'confirm_deploy=false' "${MAIN}"; then
  echo "FAIL: preview-skip-gate must match confirm_deploy=false" >&2
  exit 1
fi

if ! grep -q 'catalog_repo' "${MAIN}"; then
  echo "FAIL: intent workflow optional_inputs must include catalog_repo" >&2
  exit 1
fi

if ! grep -q 'awscli' "${MAIN}"; then
  echo "FAIL: ubuntu install_tools must include awscli" >&2
  exit 1
fi

if ! grep -q 'stack_count=0' "${MAIN}"; then
  echo "FAIL: inventory-empty-gate must match stack_count=0" >&2
  exit 1
fi

if grep -A8 'quality-rework-loop' "${MAIN}" | grep -q 'validate_blocked:'; then
  echo "FAIL: quality-rework-loop exit_match must not include validate_blocked (infra false positives)" >&2
  exit 1
fi

if ! grep -q 'confirm_deploy' "${MAIN}"; then
  echo "FAIL: preview-skip-gate must key off confirm_deploy" >&2
  exit 1
fi

if ! grep -q 'CFN_AUTHOR_SCRIPT_PACK_TARBALL_B64' "${MAIN}"; then
  echo "FAIL: ubuntu env_vars must set CFN_AUTHOR_SCRIPT_PACK_TARBALL_B64" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/scripts/security-guardrails.sh" ]]; then
  echo "FAIL: security-guardrails.sh script must exist" >&2
  exit 1
fi

if ! grep -q 'enable_cce' "${ROOT}/variables.tf"; then
  :
else
  echo "FAIL: enable_cce must be removed from cfn-author variables" >&2
  exit 1
fi

if ! grep -q 'spawn_contract_architecture_fit' "${SPAWN}"; then
  echo "FAIL: spawn_contracts must register architecture-fit-runner" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_intent_architecture_fit' "${MAIN}"; then
  echo "FAIL: architecture-fit-review must set spawn_contracts" >&2
  exit 1
fi

if ! grep -q 'architecture-blocked-gate' "${MAIN}"; then
  echo "FAIL: intent workflow must include architecture-blocked-gate" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/scripts/architecture-lint.sh" ]]; then
  echo "FAIL: architecture-lint.sh script must exist" >&2
  exit 1
fi

if [[ ! -f "${ROOT}/docs/cfn-author/review-patterns/high-throughput-web.md" ]]; then
  echo "FAIL: high-throughput-web review pattern doc must exist" >&2
  exit 1
fi

for skill in cfn-developer-intent-handler cfn-company-best-practices cfn-template-catalog-discovery cfn-architecture-fit-review; do
  if [[ ! -f "${ROOT}/skills/${skill}.md" ]]; then
    echo "FAIL: missing skill ${skill}.md" >&2
    exit 1
  fi
done

echo "OK: cfn-author workflow structure checks passed"
