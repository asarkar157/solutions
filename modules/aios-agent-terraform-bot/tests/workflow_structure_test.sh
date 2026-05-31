#!/usr/bin/env bash
# Static checks for the linear terraform-module-update workflow in main.tf.
# Run from repo root: modules/aios-agent-terraform-bot/tests/workflow_structure_test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"

required_stages=(
  check-info-and-clone
  check-info-blocked-gate
  implement-module
  validate-and-test
  validate-infra-gate
  validate-loop-gate
  create-pr
)

for stage in "${required_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing stage_id ${stage} in main.tf" >&2
    exit 1
  fi
done

retired=(
  intake
  security-scan-and-plan
  deployment-impact-scan
  parallel-tracks-fan-in
  merge-module-codegen
  merge-test-pr-and-push
  module-quality-assess
  register-and-notify
)

for stage in "${retired[@]}"; do
  if grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: retired stage_id ${stage} still present in main.tf" >&2
    exit 1
  fi
done

if ! grep -q 'check-info-blocked-gate' "${MAIN}"; then
  echo "FAIL: main.tf missing check-info-blocked-gate conditional_skip" >&2
  exit 1
fi

if ! grep -q 'validate-and-test → validate-infra-gate' "${ROOT}/templates/terraform-bot-orchestration-extensions.md.tftpl"; then
  echo "FAIL: orchestration extensions missing linear workflow diagram with infra gate" >&2
  exit 1
fi

if ! grep -q 'workflow-script-pack' "${ROOT}/main.tf"; then
  echo "FAIL: main.tf missing workflow script pack wiring" >&2
  exit 1
fi

if ! grep -q 'sop_workflow_script_pack' "${ROOT}/main.tf"; then
  echo "FAIL: main.tf missing sop_workflow_script_pack local" >&2
  exit 1
fi

for script in stage-runner.sh clone-pack.sh clone-and-notes.sh validate-module.sh; do
  if [ ! -f "${ROOT}/scripts/${script}" ]; then
    echo "FAIL: missing scripts/${script}" >&2
    exit 1
  fi
done

if ! grep -qE 'WORK_ROOT=|<WORK_ROOT>|work_root' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack missing WORK_ROOT handoff" >&2
  exit 1
fi

if ! grep -q 'workflow_run_id' "${ROOT}/templates/terraform-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP missing workflow_run_id handoff" >&2
  exit 1
fi

if ! grep -q 'action_type[[:space:]]*=[[:space:]]*"loop_stage"' "${MAIN}"; then
  echo "FAIL: validate-loop-gate must use loop_stage action_type" >&2
  exit 1
fi

if ! grep -q 'validate-infra-gate' "${MAIN}"; then
  echo "FAIL: main.tf missing validate-infra-gate conditional_skip" >&2
  exit 1
fi

if ! grep -q 'action_type[[:space:]]*=[[:space:]]*"conditional_skip"' "${MAIN}"; then
  echo "FAIL: validate-infra-gate must use conditional_skip action_type" >&2
  exit 1
fi

if ! grep -q 'module_quality_summary: BLOCKED' "${ROOT}/templates/module-quality-sop.md.tftpl"; then
  echo "FAIL: module-quality-sop missing BLOCKED sentinel guidance" >&2
  exit 1
fi

if ! grep -q '"action":"GO_BACK"' "${MAIN}"; then
  echo "FAIL: create-pr must block when predecessor emits GO_BACK JSON" >&2
  exit 1
fi

if ! grep -q 'mock_provider' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack must require mock_provider in scaffolds" >&2
  exit 1
fi

if ! grep -q 'clone_blocker=(auth|auth_or_network|network|404|branch)' "${MAIN}"; then
  echo "FAIL: check-info-blocked-gate must match all clone_blocker values (not gh_env_present alone)" >&2
  exit 1
fi

blocked_gate_match="$(awk '/stage_id[[:space:]]*=[[:space:]]*"check-info-blocked-gate"/{found=1} found && /match[[:space:]]*=/ {print; exit}' "${MAIN}")"
if [ -z "$blocked_gate_match" ]; then
  echo "FAIL: could not find check-info-blocked-gate match regex in main.tf" >&2
  exit 1
fi
if grep -q 'gh_env_present=false' <<<"$blocked_gate_match"; then
  echo "FAIL: check-info-blocked-gate match must NOT include gh_env_present=false" >&2
  exit 1
fi

if ! grep -q 'push_requires_token' "${MAIN}"; then
  echo "FAIL: create-pr must document push_requires_token push-auth path" >&2
  exit 1
fi

if ! grep -q 'clone_auth_mode' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack must document clone_auth_mode" >&2
  exit 1
fi

if ! grep -q 'fmt_exit=' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner validate must emit fmt_exit markers" >&2
  exit 1
fi

if ! grep -q 'quality_check_terraform' "${ROOT}/templates/module-quality-sop.md.tftpl"; then
  echo "FAIL: module-quality-sop must forbid synthesized quality_check_terraform" >&2
  exit 1
fi

if grep -q 'Approved subagents ONLY:.*implement-module-clone' "${ROOT}/main.tf"; then
  echo "FAIL: main.tf must not approve implement-module-clone subagent" >&2
  exit 1
fi

if ! grep -q 'resolve_repo_dir' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must normalize legacy repo_clone path" >&2
  exit 1
fi

if ! grep -q 'printf.*fake PASS' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: validate spawn contract must forbid printf fake PASS" >&2
  exit 1
fi

if ! grep -q '/bin/bash -s clone' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack must use /bin/bash -s clone heredoc pattern" >&2
  exit 1
fi

if ! grep -q 'sh -c' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack must document sh -c execute_series behavior" >&2
  exit 1
fi

if grep -q 'define _embed_tfbot_run' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn contracts must not instruct define _embed_tfbot_run wrappers" >&2
  exit 1
fi

if ! grep -q 'TFBOT_EMBEDDED' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must require TFBOT_EMBEDDED invocation" >&2
  exit 1
fi

if ! grep -q 'TFBOT_STAGE_RUNNER_SHA256' "${MAIN}"; then
  echo "FAIL: main.tf must expose TFBOT_STAGE_RUNNER_SHA256 in stage binding notes" >&2
  exit 1
fi

if awk '/sub_agent_name = "check-info-and-clone-clone"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '"load_skill"'; then
  echo "FAIL: clone spawn contract tool_names must not include load_skill (split tool calls break embed)" >&2
  exit 1
fi

if grep -q 'spawn_contract_create_pr_comment' "${ROOT}/spawn_contracts.tf" \
  && awk '/spawn_contracts_check_info_and_clone/,/\]/' "${ROOT}/spawn_contracts.tf" | grep -q 'spawn_contract_create_pr_comment'; then
  echo "FAIL: check-info spawn contracts must not include create-pr-comment (blocked gate owns notify)" >&2
  exit 1
fi

echo "OK: workflow structure checks passed"
