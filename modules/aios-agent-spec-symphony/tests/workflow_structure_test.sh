#!/usr/bin/env bash
# Static checks for spec-driven-feature workflow.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"
LINEAR="${ROOT}/workflows_linear.tf"

required_stages=(
  intake-clone-bootstrap
  intake-blocked-gate
  repo-sdd-bootstrap
  author-spec
  author-blocked-gate
  implement
  implement-blocked-gate
  validate-and-test
  validate-loop-gate
  spec-evidence-gate
  create-pr
  update-tracker
)

for stage in "${required_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing stage_id ${stage}" >&2
    exit 1
  fi
done

for removed in validate-infra-gate ci-evidence-gate archive-specs; do
  if grep -q "stage_id[[:space:]]*=[[:space:]]*\"${removed}\"" "${MAIN}"; then
    echo "FAIL: lean workflow must not include stage ${removed}" >&2
    exit 1
  fi
done

for script in stage-runner.sh clone-pack.sh spec-bootstrap.sh author-spec.sh linear-spec-materialize.sh cursor-agent.sh cursor-implement.sh cursor-author-spec.sh validate.sh ci-spec-linkage.sh ensure-shell-tool.sh blocker-comment.sh; do
  if [ ! -x "${ROOT}/scripts/${script}" ]; then
    echo "FAIL: missing or non-executable scripts/${script}" >&2
    exit 1
  fi
done

if ! grep -q 'spawn_contracts_intake_clone' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts.tf missing intake clone contracts" >&2
  exit 1
fi

if ! grep -q '"github_receiver"' "${ROOT}/webhooks.tf"; then
  echo "FAIL: webhooks.tf missing github_receiver" >&2
  exit 1
fi

if ! grep -q '"linear_receiver"' "${ROOT}/webhooks.tf"; then
  echo "FAIL: webhooks.tf missing linear_receiver" >&2
  exit 1
fi

if ! grep -q '"linear_product_spec_receiver"' "${ROOT}/webhooks.tf"; then
  echo "FAIL: webhooks.tf missing linear_product_spec_receiver" >&2
  exit 1
fi

if ! grep -q '"linear_spec_implement_receiver"' "${ROOT}/webhooks.tf"; then
  echo "FAIL: webhooks.tf missing linear_spec_implement_receiver" >&2
  exit 1
fi

if ! grep -q 'resource "sg_workflow" "linear_product_spec"' "${LINEAR}"; then
  echo "FAIL: workflows_linear.tf missing linear_product_spec workflow" >&2
  exit 1
fi

if ! grep -q 'resource "sg_workflow" "linear_spec_implement"' "${LINEAR}"; then
  echo "FAIL: workflows_linear.tf missing linear_spec_implement workflow" >&2
  exit 1
fi

if ! grep -q 'needs-spec-gate' "${LINEAR}"; then
  echo "FAIL: linear-product-spec must include needs-spec-gate" >&2
  exit 1
fi

if ! grep -q 'blessed-gate' "${LINEAR}"; then
  echo "FAIL: linear-spec-implement must include blessed-gate" >&2
  exit 1
fi

if ! grep -q 'post-linear-spec-comment' "${LINEAR}"; then
  echo "FAIL: linear-product-spec must include post-linear-spec-comment" >&2
  exit 1
fi

if ! grep -q 'post-linear-implement-comment' "${LINEAR}"; then
  echo "FAIL: linear-spec-implement must include post-linear-implement-comment" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_post_linear_spec_comment' "${ROOT}/spawn_contracts_linear.tf"; then
  echo "FAIL: spawn_contracts_linear.tf missing Linear MCP post-spec contracts" >&2
  exit 1
fi

if [ ! -f "${ROOT}/templates/sdd-kit-starter/golden-product-spec.md" ]; then
  echo "FAIL: missing golden-product-spec.md template" >&2
  exit 1
fi

if ! grep -q 'remote_runners' "${MAIN}"; then
  echo "FAIL: main.tf must attach remote_runners to orchestrator" >&2
  exit 1
fi

if grep -q 'use_ubuntu_integration' "${MAIN}"; then
  echo "FAIL: spec-symphony must not use Ubuntu integration" >&2
  exit 1
fi

if ! grep -q 'context canceled' "${MAIN}"; then
  echo "FAIL: intake-blocked-gate must match context canceled (runner offline)" >&2
  exit 1
fi

if ! grep -q 'malformed_work_root' "${MAIN}"; then
  echo "FAIL: intake-blocked-gate must match malformed_work_root" >&2
  exit 1
fi

if ! grep -q 'clone-execute-series-embedded.sh.tftpl' "${MAIN}"; then
  echo "FAIL: main.tf must wire clone-execute-series-embedded template" >&2
  exit 1
fi

if ! grep -q 'blocker-comment.sh' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must invoke blocker-comment.sh for notify" >&2
  exit 1
fi

if ! grep -q 'Spawn discipline' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must forbid custom goal/context on spawn" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_archive' "${MAIN}"; then
  echo "FAIL: update-tracker must concat spawn_contracts_archive (lean: no archive-specs stage)" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_author_spec' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts.tf missing author-spec contracts" >&2
  exit 1
fi

if ! grep -q 'implement-cursor-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts.tf missing implement-cursor-runner contract" >&2
  exit 1
fi

if ! grep -q 'spec-evidence-gate' "${MAIN}"; then
  echo "FAIL: main.tf must include spec-evidence-gate before create-pr" >&2
  exit 1
fi

if ! grep -q 'policy_create_flags' "${MAIN}"; then
  echo "FAIL: main.tf must use policy_create_flags for spec_traceability attachment count" >&2
  exit 1
fi

if ! grep -q 'spec_linkage_recorded' "${MAIN}"; then
  echo "FAIL: evidence checklist must include spec_linkage_recorded" >&2
  exit 1
fi

validate_binding_block="$(awk '
  /stage_id[[:space:]]*=[[:space:]]*"validate-and-test"/ { block=1; buf=$0; next }
  block {
    buf=buf "\n" $0
    if (/agent_ref/) { has_agent=1 }
    if (/action_type/) { has_action=1 }
    if (/^[[:space:]]*\},/) {
      if (has_agent) { print buf; exit }
      block=0; buf=""; has_agent=0; has_action=0
    }
  }
' "${MAIN}")"
if [ -z "$validate_binding_block" ]; then
  echo "FAIL: validate-and-test stage_binding must set agent_ref (not loop_stage; trace e22cc371)" >&2
  exit 1
fi
if grep -q 'action_type' <<<"$validate_binding_block"; then
  echo "FAIL: validate-and-test must not set action_type (only validate-loop-gate is loop_stage)" >&2
  exit 1
fi

loop_exit="$(awk '/stage_id[[:space:]]*=[[:space:]]*"validate-loop-gate"/{c++} c>=2 && /exit_condition/{print; exit}' "${MAIN}")"
if ! grep -q 'output_matches_regex' <<<"$loop_exit"; then
  echo "FAIL: validate-loop-gate must use output_matches_regex" >&2
  exit 1
fi

loop_match="$(awk '/stage_id[[:space:]]*=[[:space:]]*"validate-loop-gate"/{c++} c>=2 && /exit_match/{print; exit}' "${MAIN}")"
if ! grep -qF 'module_quality_summary[=:]' <<<"$loop_match"; then
  echo "FAIL: validate-loop-gate exit_match must match module_quality_summary=PASS|BLOCKED" >&2
  exit 1
fi

loop_depends="$(awk '
  /stage_id[[:space:]]*=[[:space:]]*"validate-loop-gate"/ { block=1; buf="" }
  block {
    buf=buf $0 "\n"
    if (/action_type[[:space:]]*=[[:space:]]*"loop_stage"/) { is_loop=1 }
    if (/stage_depends_on/ && is_loop) { print buf; exit }
  }
' "${MAIN}")"
if ! grep -q 'validate-and-test' <<<"$loop_depends"; then
  echo "FAIL: validate-loop-gate must depend on validate-and-test directly (no validate-infra-gate)" >&2
  exit 1
fi

echo "OK: spec-symphony workflow structure checks passed"
