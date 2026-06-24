#!/usr/bin/env bash
# Static checks for the linear cdk-app-update workflow in main.tf.
# Run from repo root: modules/aios-agent-cdk-bot/tests/workflow_structure_test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"
OUTPUTS="${ROOT}/outputs.tf"

if ! grep -q 'stackgen_webhook_trigger_url.*/guild/api/v1/webhooks/trigger' "${MAIN}"; then
  echo "FAIL: main.tf must build webhook URL with /guild/api/v1/webhooks/trigger for public StackGen ingress" >&2
  exit 1
fi

if ! grep -q 'local.stackgen_webhook_trigger_url' "${OUTPUTS}"; then
  echo "FAIL: outputs.tf must use local.stackgen_webhook_trigger_url for webhook_trigger_endpoint and ingress URL" >&2
  exit 1
fi

if ! grep -q 'spawn_contract_progress_comment' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts.tf missing progress-comment-updater spawn contract" >&2
  exit 1
fi

if ! grep -q 'enable_progress_issue_comment' "${ROOT}/variables.tf"; then
  echo "FAIL: variables.tf missing enable_progress_issue_comment" >&2
  exit 1
fi

if ! grep -q 'progress-comment-execute-series-embedded' "${ROOT}/main.tf"; then
  echo "FAIL: main.tf must load progress-comment-execute-series-embedded template" >&2
  exit 1
fi

if ! grep -q 'Template P' "${ROOT}/templates/cdk-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP missing Template P progress comment" >&2
  exit 1
fi

required_stages=(
  clone
  clone-blocked-gate
  implement-cdk
  implement-blocked-gate
  validate
  validate-loop-gate
)

for stage in "${required_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing stage_id ${stage} in main.tf" >&2
    exit 1
  fi
done

retired=(
  intake
  intake-clone-bootstrap
  intake-blocked-gate
  edit
  implement-spawn-gate
  catalog-greenfield-skip-gate
  validate-and-test
  validate-infra-gate
  validate-draft-pr-gate
  create-pr
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

if ! grep -q 'clone-blocked-gate' "${MAIN}"; then
  echo "FAIL: main.tf missing clone-blocked-gate conditional_skip" >&2
  exit 1
fi

if ! grep -q 'validate-loop-gate ↺ implement-cdk' "${ROOT}/templates/cdk-bot-orchestration-extensions.md.tftpl"; then
  echo "FAIL: orchestration extensions missing 3-stage workflow diagram" >&2
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

for script in stage-runner.sh clone-pack.sh clone-and-notes.sh validate-cdk.sh detect-cdk-language.sh ensure-cdk-toolchain.sh ensure-shell-tool.sh bootstrap-deps.sh; do
  if [ ! -f "${ROOT}/scripts/${script}" ]; then
    echo "FAIL: missing scripts/${script}" >&2
    exit 1
  fi
done

if ! grep -qE 'WORK_ROOT=|<WORK_ROOT>|work_root' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack missing WORK_ROOT handoff" >&2
  exit 1
fi

if ! grep -q 'workflow_run_id' "${ROOT}/templates/cdk-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP missing workflow_run_id handoff" >&2
  exit 1
fi

if ! grep -q 'action_type[[:space:]]*=[[:space:]]*"loop_stage"' "${MAIN}"; then
  echo "FAIL: validate-loop-gate must use loop_stage action_type" >&2
  exit 1
fi

if ! grep -q 'loop_to[[:space:]]*=[[:space:]]*"implement-cdk"' "${MAIN}"; then
  echo "FAIL: validate-loop-gate must set loop_to implement-cdk (edit stage)" >&2
  exit 1
fi

loop_to_target="$(awk '/stage_id[[:space:]]*=[[:space:]]*"validate-loop-gate"/,/^[[:space:]]*},/' "${MAIN}" | awk -F'"' '/loop_to/ {print $2; exit}')"
if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${loop_to_target}\"" "${MAIN}"; then
  echo "FAIL: validate-loop-gate loop_to target ${loop_to_target} must exist as a stage_id in main.tf" >&2
  exit 1
fi

while IFS= read -r dep; do
  [ -z "${dep}" ] && continue
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${dep}\"" "${MAIN}"; then
    echo "FAIL: stage_depends_on references unknown stage_id \"${dep}\"" >&2
    exit 1
  fi
done < <(grep 'stage_depends_on[[:space:]]*=' "${MAIN}" | grep -oE '"[a-z0-9-]+"' | tr -d '"' | sort -u)

if ! grep -q 'spawn_contracts_commit_pr' "${MAIN}"; then
  echo "FAIL: edit stage must include spawn_contracts_commit_pr (draft PR after implement)" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_validate_followup' "${MAIN}"; then
  echo "FAIL: validate stage must include spawn_contracts_validate_followup (notify/comment)" >&2
  exit 1
fi

if ! grep -q 'module_quality_summary: BLOCKED' "${ROOT}/templates/module-quality-sop.md.tftpl"; then
  echo "FAIL: module-quality-sop missing BLOCKED sentinel guidance" >&2
  exit 1
fi

STAGE_NOTES="${ROOT}/templates/stage-notes"

if ! grep -q 'validate-loop-gate' "${STAGE_NOTES}/validate.md.tftpl"; then
  echo "FAIL: validate stage note must document validate-loop-gate" >&2
  exit 1
fi

if ! grep -q 'mock_provider\|Template.fromStack' "${ROOT}/templates/catalog-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: catalog scaffold template must require assertion tests (Template.fromStack or mock_provider)" >&2
  exit 1
fi

if ! grep -qE 'clone_blocker=\(auth\|auth_or_network\|network\|404\|branch\|placeholder_url\|missing_clone_params\|repo_not_found_or_auth\|missing_script_pack\|wrong_shell_dollar_escape\|shell_runner_incompatible\|unexpanded_shell_var\)' "${MAIN}"; then
  echo "FAIL: clone-blocked-gate must match all clone_blocker values" >&2
  exit 1
fi

blocked_gate_block="$(awk '/stage_id[[:space:]]*=[[:space:]]*"clone-blocked-gate"/,/^[[:space:]]*},/' "${MAIN}" | awk '/action_type[[:space:]]*=[[:space:]]*"conditional_skip"/,/^    },/')"
if [ -z "$blocked_gate_block" ]; then
  echo "FAIL: could not find clone-blocked-gate conditional_skip block in main.tf" >&2
  exit 1
fi
if ! grep -q 'skip_to[[:space:]]*=[[:space:]]*"validate"' <<<"$blocked_gate_block"; then
  echo "FAIL: clone-blocked-gate must skip_to validate" >&2
  exit 1
fi

if ! grep -q 'push_requires_token' "${STAGE_NOTES}/validate.md.tftpl"; then
  echo "FAIL: validate stage note must document push_requires_token path" >&2
  exit 1
fi

if ! grep -q 'stage_runner_path' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack must document stage_runner_path materialization" >&2
  exit 1
fi

if ! grep -q 'fmt_exit=' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner validate must emit fmt_exit markers" >&2
  exit 1
fi

if ! grep -q 'quality_check_lint' "${ROOT}/templates/module-quality-sop.md.tftpl"; then
  echo "FAIL: module-quality-sop must document quality_check_lint sentinels" >&2
  exit 1
fi

if grep -q 'Approved subagents ONLY:.*implement-cdk-clone' "${ROOT}/main.tf"; then
  echo "FAIL: main.tf must not approve implement-cdk-clone subagent" >&2
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

if ! grep -q 'spawn context' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack must reference spawn context blocks" >&2
  exit 1
fi

if ! grep -q 'sh -c' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack must document sh -c execute_series behavior" >&2
  exit 1
fi

if ! grep -q 'tftpl / goal safety' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack must document tftpl dollar-sign escaping" >&2
  exit 1
fi

if grep -qE '→ \$\{[A-Za-z_]+\}' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack has unescaped \${...} after arrow (breaks templatefile)" >&2
  exit 1
fi

if grep -q 'define _embed_cdkbot_run' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn contracts must not instruct define _embed_cdkbot_run wrappers" >&2
  exit 1
fi

if ! grep -q 'CDKBOT_EMBEDDED' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must require CDKBOT_EMBEDDED invocation" >&2
  exit 1
fi

if ! grep -q 'CDKBOT_STAGE_RUNNER_SHA256' "${STAGE_NOTES}/clone.md.tftpl"; then
  echo "FAIL: clone stage note must expose CDKBOT_STAGE_RUNNER_SHA256" >&2
  exit 1
fi
if ! grep -q 'clone_stage_note' "${MAIN}"; then
  echo "FAIL: main.tf must wire compact clone stage note template" >&2
  exit 1
fi

if awk '/sub_agent_name = "clone-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '"load_skill"'; then
  echo "FAIL: clone spawn contract tool_names must not include load_skill (split tool calls break embed)" >&2
  exit 1
fi

if grep -q 'spawn_contract_create_pr_comment' "${ROOT}/spawn_contracts.tf" \
  && awk '/spawn_contracts_check_info_and_clone/,/\]/' "${ROOT}/spawn_contracts.tf" | grep -q 'spawn_contract_create_pr_comment'; then
  echo "FAIL: check-info spawn contracts must not include create-pr-comment (blocked gate owns notify)" >&2
  exit 1
fi

if grep -q '^---BEGIN CLONE_EXECUTE_SERIES---' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not embed full clone body (causes LLM truncation); use CLONE_ONE_LINER header only" >&2
  exit 1
fi

if grep -qE '^CLONE_ONE_LINER:' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not expose CLONE_ONE_LINER header (agents truncate base64); use CDKBOT_PACK_DIR/clone-pack.sh" >&2
  exit 1
fi

if ! grep -q 'cdkbot_pack_dir' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn context must expose CDKBOT_PACK_DIR / cdkbot_pack_dir for clone-pack.sh" >&2
  exit 1
fi

if ! grep -q 'clone-pack.sh clone' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: clone spawn context must document clone-pack.sh clone command" >&2
  exit 1
fi

if ! grep -q 'cdkbot_pack_ensure_shell' "${ROOT}/main.tf"; then
  echo "FAIL: main.tf must define cdkbot_pack_ensure_shell inline ensure (no PATH dependency)" >&2
  exit 1
fi

if grep -q '\$\$PD' "${ROOT}/main.tf" || grep -q '\$\$CDKBOT' "${ROOT}/main.tf"; then
  echo "FAIL: cdkbot_pack_ensure_shell must use heredoc single \$ (not \$\$PD/\$\$CDKBOT — bash PID expansion in agent commands)" >&2
  exit 1
fi

if ! grep -q 'shell_execute_series_shell_dollar_rule' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must document single-\$ rule for shell execute_series" >&2
  exit 1
fi

if ! grep -q 'wrong_shell_dollar_escape' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must distinguish wrong_shell_dollar_escape from missing_script_pack" >&2
  exit 1
fi

if ! grep -q 'cdkbot_pack_ensure_shell' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: clone spawn must use cdkbot_pack_ensure_shell before clone-pack.sh" >&2
  exit 1
fi

if ! grep -q 'CDKBOT_SCRIPT_PACK_TARBALL_B64' "${MAIN}" && ! grep -q 'COPY --chown=runner:runner scripts/' "${ROOT}/docker/Dockerfile"; then
  echo "FAIL: remote runner must sync script pack tarball via secret or bake scripts/ in Docker image" >&2
  exit 1
fi

if ! grep -q 'module "remote_runner"' "${MAIN}"; then
  echo "FAIL: main.tf must provision aios-remote-runner" >&2
  exit 1
fi

if grep -q 'ubuntu_integration\|use_ubuntu_integration' "${MAIN}" "${ROOT}/variables.tf"; then
  echo "FAIL: cdk-bot must not provision Ubuntu integration (remote runner only)" >&2
  exit 1
fi

if ! grep -q 'null_resource' "${ROOT}/docker.tf"; then
  echo "FAIL: docker.tf must build CDK runner image via null_resource" >&2
  exit 1
fi

if ! grep -q 'remote_runners' "${MAIN}"; then
  echo "FAIL: sg_agent must attach remote_runners when using CDK runner" >&2
  exit 1
fi

if ! grep -q 'shell_tool_prefix' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must reference shell_tool_prefix for execute_* tools" >&2
  exit 1
fi

if ! grep -q 'clone-execute-series-embedded.sh.tftpl' "${ROOT}/main.tf"; then
  echo "FAIL: main.tf must wire clone-execute-series-embedded template" >&2
  exit 1
fi

if ! grep -q "stage-runner.sh validate '{{work_root}}'" "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: validate spawn must pass {{work_root}} argv to stage-runner validate (trace eed7f3b6)" >&2
  exit 1
fi

if awk '/Validate-only command/,/^FORBIDDEN/' "${ROOT}/spawn_contracts.tf" | grep -q 'stage-runner.sh validate-and-pr'; then
  echo "FAIL: validate spawn context must not invoke validate-and-pr (PR opens in edit)" >&2
  exit 1
fi

if ! grep -q 'stage-runner.sh commit-pr' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts commit-pr context must use short stage-runner commit-pr one-liner" >&2
  exit 1
fi

if ! grep -q 'skipping commit-pr execute_series because pr_url is set' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: create-pr-runner must forbid skipping commit-pr execute_series on rework when pr_url is set" >&2
  exit 1
fi

if grep -q '^VALIDATE_ONE_LINER:' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn context must not expose VALIDATE_ONE_LINER header (causes quote breakage in sh -c)" >&2
  exit 1
fi

if grep -q '^---BEGIN VALIDATE_EXECUTE_SERIES---' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not embed full validate body (causes TRIGGER_JSON inline + LLM truncation)" >&2
  exit 1
fi

if ! awk '/Progress comment command/,/^FORBIDDEN/' "${ROOT}/spawn_contracts.tf" | grep -qE 'REPO_FULL_NAME=.*progress-comment\.sh'; then
  echo "FAIL: progress spawn must prefix REPO_FULL_NAME on progress-comment.sh subprocess (trace eed7f3b6)" >&2
  exit 1
fi

if ! awk '/Discovery command \(short/,/^Optional overrides/' "${ROOT}/spawn_contracts.tf" | grep -qE 'ISSUE_TITLE=.*catalog-scaffold'; then
  echo "FAIL: discovery spawn must prefix ISSUE_TITLE on catalog-scaffold subprocess (trace eed7f3b6)" >&2
  exit 1
fi

if ! grep -q 'normalize-work-root' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: implement-app spawn must use normalize-work-root for parent-shell WR assignment (trace eed7f3b6)" >&2
  exit 1
fi

if ! grep -q 'CDKBOT_ALLOW_DIRECT=1.*stage-runner.sh normalize-work-root' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: implement spawn must prefix CDKBOT_ALLOW_DIRECT=1 on normalize-work-root subprocess" >&2
  exit 1
fi

if ! grep -q 'implement_blocker=edit_script_missing' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: implement series 2 must guard missing EDIT_SH file before implement-app-run" >&2
  exit 1
fi

if ! grep -q "commit-pr '{{work_root}}'" "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: commit-pr spawn must pass {{work_root}} argv to stage-runner commit-pr" >&2
  exit 1
fi

if grep 'stage-runner.sh commit-pr' "${ROOT}/spawn_contracts.tf" | grep -q "WORKING_BRANCH='<working_branch"; then
  echo "FAIL: commit-pr spawn command must not embed WORKING_BRANCH angle-bracket placeholder (trace 30cad5fbade9)" >&2
  exit 1
fi

if ! grep -q 'resolve_working_branch' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must resolve WORKING_BRANCH spawn placeholders" >&2
  exit 1
fi

if ! grep -q 'prepare-implement-edits' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: implement-app spawn context must invoke prepare-implement-edits" >&2
  exit 1
fi

if grep -q "mkdir -p '{{work_root}}/.work'" "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: implement-app spawn must not mkdir with single-quoted {{work_root}} (trace b9401899c86d)" >&2
  exit 1
fi

if ! grep -q 'implement-app-run' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: implement-app spawn context must invoke implement-app-run" >&2
  exit 1
fi

if ! grep -q 'Edit blocked' "${STAGE_NOTES}/validate.md.tftpl"; then
  echo "FAIL: validate stage note must handle edit-blocked path" >&2
  exit 1
fi

if ! grep -q 'plan-only' "${STAGE_NOTES}/edit.md.tftpl"; then
  echo "FAIL: edit stage note must forbid plan-only success prose (trace 3a3b97ab)" >&2
  exit 1
fi

if grep -q '^---BEGIN DISCOVERY_SCAFFOLD_EXECUTE_SERIES---' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not embed full discovery body (causes TRIGGER_JSON inline + LLM truncation)" >&2
  exit 1
fi

if ! grep -q 'catalog-scaffold' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: discovery spawn must use stage-runner catalog-scaffold command" >&2
  exit 1
fi

if ! grep -q 'TRIGGER_JSON_B64' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: discovery spawn must use TRIGGER_JSON_B64 not inline TRIGGER_JSON" >&2
  exit 1
fi

if ! grep -q 'cdk_spawn_context_validate' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must define per-stage cdk_spawn_context_validate" >&2
  exit 1
fi

if ! grep -q 'stage_runner_path=' "${ROOT}/scripts/clone-pack.sh"; then
  echo "FAIL: clone-pack.sh must copy stage-runner to .pack and emit stage_runner_path" >&2
  exit 1
fi

if ! grep -q '.pack/stage-runner.sh' "${ROOT}/templates/validate-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: validate template must invoke .pack/stage-runner.sh (not embed full script)" >&2
  exit 1
fi

pack_bytes="$(wc -c < "${ROOT}/templates/workflow-script-pack.md.tftpl" | tr -d ' ')"
if [ "$pack_bytes" -gt 12000 ]; then
  echo "FAIL: workflow-script-pack template too large (${pack_bytes} bytes) — causes load_skill auto-summarization" >&2
  exit 1
fi

if ! grep -q "bin/bash <<'CDKBOT_DISCOVERY_SCAFFOLD'" "${ROOT}/templates/catalog-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: catalog scaffold embedded template must self-wrap in /bin/bash heredoc" >&2
  exit 1
fi

if ! grep -q 'create-pr-runner' "${STAGE_NOTES}/edit.md.tftpl"; then
  echo "FAIL: edit stage note must document create-pr-runner after implement" >&2
  exit 1
fi

if grep -q 'create-pr-runner' "${STAGE_NOTES}/validate.md.tftpl" && ! grep -q 'Forbidden: `create-pr-runner`' "${STAGE_NOTES}/validate.md.tftpl"; then
  echo "FAIL: validate stage note must forbid create-pr-runner (PR opens in edit)" >&2
  exit 1
fi

if ! grep -q 'pr_draft' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must emit pr_draft and use gh pr create --draft on quality failures" >&2
  exit 1
fi

if ! grep -qE 'bash -s validate|stage-runner\.sh validate' "${ROOT}/templates/validate-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: validate template must invoke stage-runner validate (checks only)" >&2
  exit 1
fi

if grep -q 'validate-and-pr' "${ROOT}/templates/validate-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: validate embed must not use validate-and-pr (PR opens in edit)" >&2
  exit 1
fi

if awk '/sub_agent_name = "validate-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '"load_skill"'; then
  echo "FAIL: validate-runner must not include load_skill" >&2
  exit 1
fi

if awk '/sub_agent_name = "implement-cdk-catalog-scaffold"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '"load_skill"'; then
  echo "FAIL: implement-cdk-catalog-scaffold must not include load_skill" >&2
  exit 1
fi

if awk '/sub_agent_name = "create-pr-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '"load_skill"'; then
  echo "FAIL: create-pr-runner spawn contract must not include load_skill" >&2
  exit 1
fi

if awk '/sub_agent_name = "create-pr-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '"read_notes"'; then
  echo "FAIL: create-pr-runner must not include read_notes (trace 2c708b834ca1 — burns budget before commit-pr)" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "create-pr-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'FIRST TOOL CALL MUST be'; then
  echo "FAIL: create-pr-runner must require execute_series as first tool call" >&2
  exit 1
fi

if ! grep -q '2c708b834ca1' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: create-pr-runner spawn contract must document trace 2c708b834ca1" >&2
  exit 1
fi

if ! grep -q 'missing pr_url' "${MAIN}"; then
  echo "FAIL: implement-blocked-gate must skip to validate on missing pr_url" >&2
  exit 1
fi

if ! grep -q 'catalog_greenfield_validated=true' "${ROOT}/templates/catalog-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold template must run inline validate and emit catalog_greenfield_validated=true" >&2
  exit 1
fi

if ! grep -q 'discovery_scaffold_execute_series_one_liner' "${MAIN}"; then
  echo "FAIL: main.tf must define discovery_scaffold_execute_series_one_liner for base64 delivery" >&2
  exit 1
fi

if grep -qE '^DISCOVERY_SCAFFOLD_ONE_LINER:' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn context must not expose DISCOVERY_SCAFFOLD_ONE_LINER header" >&2
  exit 1
fi

if ! grep -q 'catalog-scaffold' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must implement catalog-scaffold command" >&2
  exit 1
fi

if ! grep -q 'validate-and-pr' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must implement validate-and-pr command" >&2
  exit 1
fi

if ! grep -q 'validate_out_fmt_validate_pass' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must gate PR on fmt+init+validate pass (not full test PASS)" >&2
  exit 1
fi

if ! grep -q 'pr_eligible_fmt_validate=true' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must emit pr_eligible_fmt_validate marker" >&2
  exit 1
fi

if ! grep -q 'pr_eligible_fmt_validate' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: validate-and-pr must emit pr_eligible_fmt_validate" >&2
  exit 1
fi
if ! grep -q 'pr_deferred=init_failed' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must emit pr_deferred=init_failed" >&2
  exit 1
fi
if grep -q 'should_open_pr=' "${ROOT}/templates/validate-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: validate embed must not duplicate PR policy in embed" >&2
  exit 1
fi

if ! grep -q 'WORK_ROOT:?export WORK_ROOT before discovery scaffold' "${ROOT}/templates/catalog-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold must require WORK_ROOT env for one-liner delivery" >&2
  exit 1
fi

if ! grep -q 'WORK_ROOT:?set WORK_ROOT before clone one-liner' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: clone execute_series must require WORK_ROOT env for one-liner delivery" >&2
  exit 1
fi

if grep -q 'WORK_ROOT="{{work_root}}"' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: clone template must not bake {{work_root}} into base64 blob" >&2
  exit 1
fi

if grep -qE 'sed.*GIT_(USERNAME|TOKEN)|sed -E.*x-access-token' "${ROOT}/templates/cdk-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP must not document sed-based auth clone URLs" >&2
  exit 1
fi

if ! grep -q 'catalog_greenfield_validated' "${STAGE_NOTES}/validate.md.tftpl"; then
  echo "FAIL: validate stage note must document catalog greenfield fast-path" >&2
  exit 1
fi

if ! grep -q 'stage-runner.sh validate ' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: validate spawn context must use stage-runner validate (not validate-and-pr)" >&2
  exit 1
fi

if grep -Fq 'pr_url=https://github\\.' <<<"$(awk '/stage_id[[:space:]]*=[[:space:]]*"validate-loop-gate"/,/loop_to/' "${MAIN}" | grep exit_match)"; then
  echo "FAIL: validate-loop-gate must not exit on pr_url alone (PR opens before validate)" >&2
  exit 1
fi
if ! grep -q 'progress-comment-updater' "${STAGE_NOTES}/validate.md.tftpl"; then
  echo "FAIL: validate stage note must document progress-comment-updater path when pr_url is set" >&2
  exit 1
fi
if ! grep -q 'note_val.*working_branch' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: commit-pr must reuse working_branch from notes" >&2
  exit 1
fi

loop_exit_match="$(awk '/stage_id[[:space:]]*=[[:space:]]*"validate-loop-gate"/{c++} c>=2 && /exit_match[[:space:]]*=/ {print; exit}' "${MAIN}")"
if [ -z "$loop_exit_match" ]; then
  echo "FAIL: could not find validate-loop-gate exit_match in main.tf" >&2
  exit 1
fi
if ! grep -qF 'module_quality_summary[^\\n]{0,48}(PASS|BLOCKED)' <<<"$loop_exit_match"; then
  echo "FAIL: validate-loop-gate must exit on BLOCKED as well as PASS (JSON or sentinel summaries)" >&2
  exit 1
fi

if ! grep -qF 'implement_blocker=' <<<"$loop_exit_match"; then
  echo "FAIL: validate-loop-gate must FINISH (not GO_BACK) when implement_blocker is present (trace 55b8fb232345)" >&2
  exit 1
fi

if ! grep -q "implement-blocked-gate" "${MAIN}"; then
  echo "FAIL: main.tf missing implement-blocked-gate conditional_skip" >&2
  exit 1
fi

if ! grep -q "'{{work_root}}/repo'" "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: implement spawn context must use {{work_root}}/repo instead of angle-bracket placeholders" >&2
  exit 1
fi

if ! grep -q 'runner_max_llm_calls      = 8' "${MAIN}"; then
  echo "FAIL: runner_max_llm_calls default must be 8" >&2
  exit 1
fi

if ! grep -q 'validate_max_llm_calls    = 12' "${MAIN}"; then
  echo "FAIL: validate_max_llm_calls default must be 12" >&2
  exit 1
fi

if awk '/skill_refs = concat/,/\)/' "${MAIN}" | grep -q 'local.sop_workflow_script_pack'; then
  echo "FAIL: embedded stage bindings must not include workflow_script_pack in skill_refs (causes load_skill bloat)" >&2
  exit 1
fi

if ! grep -q 'halguard_skip_subagent_task_types' "${MAIN}"; then
  echo "FAIL: workflow metadata must include halguard_skip_subagent_task_types hint" >&2
  exit 1
fi

if ! grep -q 'github_max_llm_calls      = 12' "${MAIN}"; then
  echo "FAIL: github_max_llm_calls default must be 12" >&2
  exit 1
fi

if ! grep -q 'implement_max_llm_calls   = 20' "${MAIN}"; then
  echo "FAIL: implement_max_llm_calls default must be 20" >&2
  exit 1
fi

if ! grep -q 'sub_agent_name = "create-pr-notify"' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must define create-pr-notify for blocked GitHub-only notify" >&2
  exit 1
fi

if ! grep -q 'validate_markers_file=' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: validate-and-pr must emit validate_markers_file for architect handoff" >&2
  exit 1
fi

if ! grep -q 'test_summary_tail' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner validate path must emit test_summary_tail on test failure" >&2
  exit 1
fi

if ! grep -q 'pick_discovery_sibling_dir' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must implement pick_discovery_sibling_dir" >&2
  exit 1
fi

if ! grep -q 'draft_pr_on_max_iterations_exhausted' "${ROOT}/variables.tf"; then
  echo "FAIL: variables.tf must define draft_pr_on_max_iterations_exhausted" >&2
  exit 1
fi

default_draft_on_exhaust="$(awk '/variable "draft_pr_on_max_iterations_exhausted"/,/^}/' "${ROOT}/variables.tf" | awk '/default[[:space:]]*=/ {print; exit}')"
if ! grep -q 'default[[:space:]]*=[[:space:]]*true' <<<"$default_draft_on_exhaust"; then
  echo "FAIL: draft_pr_on_max_iterations_exhausted default must be true" >&2
  exit 1
fi

if ! grep -qE 'Loop exhaust|max iterations' "${STAGE_NOTES}/validate.md.tftpl"; then
  echo "FAIL: validate stage note must document loop-exhaust / max-iter precedence" >&2
  exit 1
fi

if ! grep -q 'script_pack_runner_b64' "${ROOT}/templates/validate-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: validate template must materialize stage-runner from base64 script pack" >&2
  exit 1
fi

if ! grep -q 'script_pack_runner_b64' "${ROOT}/templates/catalog-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold template must materialize stage-runner from base64 script pack" >&2
  exit 1
fi

if ! grep -q 'scaffold_error=invalid_json' "${ROOT}/templates/catalog-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold must validate variables.tf.json before validate" >&2
  exit 1
fi

if ! grep -q 'lint_exit' "${ROOT}/scripts/validate-cdk.sh"; then
  echo "FAIL: validate-cdk must emit lint_exit markers" >&2
  exit 1
fi

if ! grep -q 'cfn_lint_exit' "${ROOT}/scripts/validate-cdk.sh"; then
  echo "FAIL: validate-cdk must emit cfn_lint_exit markers" >&2
  exit 1
fi

if ! grep -q 'nag_exit' "${ROOT}/scripts/validate-cdk.sh"; then
  echo "FAIL: validate-cdk must emit nag_exit markers" >&2
  exit 1
fi


if ! grep -q 'clone_blocker=placeholder_url' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: clone template must emit clone_blocker=placeholder_url for invented URLs" >&2
  exit 1
fi

if ! grep -q 'execute_series_working_dir' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn context must expose execute_series_working_dir for shell execute_series" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "clone-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'shell_execute_series_working_dir_rule'; then
  echo "FAIL: clone spawn contract must forbid WORK_ROOT as execute_series working_dir" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "clone-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -qE 'COPY spawn-context Clone|COPY VERBATIM|trace 0bf8c7ef'; then
  echo "FAIL: clone spawn contract must require COPY VERBATIM spawn-context clone command (trace 0bf8c7ef)" >&2
  exit 1
fi

if ! grep -q 'unexpanded_shell_var' "${ROOT}/scripts/clone-pack.sh"; then
  echo "FAIL: clone-pack.sh must emit clone_blocker=unexpanded_shell_var for literal \$REPO_CLONE_URL argv" >&2
  exit 1
fi

if awk '/sub_agent_name = "clone-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -qE "When notes empty export TRIGGER_JSON='|export WORK_ROOT='[^']+' TRIGGER_JSON='\\{"; then
  echo "FAIL: clone spawn contract must not instruct inline TRIGGER_JSON in shell command" >&2
  exit 1
fi

if awk '/sub_agent_name = "clone-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -qE 'paste CLONE_ONE_LINER|&& CLONE_ONE_LINER|CLONE_ONE_LINER from'; then
  echo "FAIL: clone spawn contract goal must not instruct pasting CLONE_ONE_LINER" >&2
  exit 1
fi

if ! grep -q '9d8958e4' "${STAGE_NOTES}/clone.md.tftpl"; then
  echo "FAIL: clone stage note should reference trace 9d8958e4 clone-order fix" >&2
  exit 1
fi

if ! grep -q 'ee933655' "${STAGE_NOTES}/edit.md.tftpl"; then
  echo "FAIL: edit stage note should reference trace ee933655 wrong-file hallucination" >&2
  exit 1
fi

pack_main="$(grep -E 'script_pack_version[[:space:]]*=' "${MAIN}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
clone_ver="$(grep 'script_pack_version=' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl" | head -1 | sed -E 's/.*=\$\{script_pack_version\}|.*=\$\{([^}]+)\}.*/\1/')"
if [ "$clone_ver" = "script_pack_version" ]; then
  clone_ver="$(grep 'script_pack_version=' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl" | tail -1 | sed -E 's/.*\$\{([^}]+)\}.*/\1/')"
fi
if [ "$pack_main" != "20260624.16" ]; then
  echo "FAIL: expected script_pack_version 20260624.16 in main.tf (got ${pack_main})" >&2
  exit 1
fi

if ! grep -q 'greenfield_working_branch_from_issue' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must derive gf branch from deliverable paths" >&2
  exit 1
fi

if ! grep -q 'create-pr-runner-retry' "${STAGE_NOTES}/edit.md.tftpl"; then
  echo "FAIL: edit stage note must document create-pr-runner-retry for spawn dedup" >&2
  exit 1
fi

if ! grep -q 'skip.*create-pr-runner' "${STAGE_NOTES}/edit.md.tftpl"; then
  echo "FAIL: edit stage note must skip create-pr-runner when pr_url already set" >&2
  exit 1
fi

if ! grep -q 'implement-cdk-app-update-retry' "${STAGE_NOTES}/edit.md.tftpl"; then
  echo "FAIL: edit stage note must document implement-cdk-app-update-retry for spawn dedup" >&2
  exit 1
fi

if ! grep -q 'lib_test_has_changes' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must detect untracked lib/test files for greenfield postcheck" >&2
  exit 1
fi

if ! grep -q 'try_builtin_g1_greenfield_recovery' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must scaffold G1 greenfield deliverables when agent edits fail" >&2
  exit 1
fi

if grep -qE '\$\$\(|print \$\$1' "${ROOT}/templates/cdkbot-pack-ensure-shell.sh.tftpl"; then
  echo "FAIL: cdkbot-pack-ensure-shell.sh.tftpl must use single \$ for command substitution (templatefile only collapses \$\${ — not \$\$() or \$\$1)" >&2
  exit 1
fi

if ! grep -q 'check-work-root-clone' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner.sh must expose check-work-root-clone for stale work-root guard (trace 9e8afbe42c8d)" >&2
  exit 1
fi

if ! grep -q 'stale_repo_clone_path' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts clone context must document stale_repo_clone_path guard" >&2
  exit 1
fi

if ! grep -q '9e8afbe42c8d' "${ROOT}/templates/stage-notes/clone.md.tftpl"; then
  echo "FAIL: clone stage note must require re-clone when repo_clone_path is outside current work_root" >&2
  exit 1
fi

if ! grep -q 'runner_script_pack_env' "${ROOT}/script_pack.tf"; then
  echo "FAIL: script_pack.tf must provision runner_script_pack_env secret for mothership sync" >&2
  exit 1
fi

if ! grep -q 'CDKBOT_SCRIPT_PACK_TARBALL_B64' "${ROOT}/script_pack.tf"; then
  echo "FAIL: runner script-pack secret must include CDKBOT_SCRIPT_PACK_TARBALL_B64" >&2
  exit 1
fi

if ! grep -q 'generic_secret_ref_ids' "${MAIN}"; then
  echo "FAIL: remote_runner module must bind generic_secret_ref_ids for script-pack sync" >&2
  exit 1
fi

if ! grep -q 'cdkbot-pack-ensure-shell.sh.tftpl' "${ROOT}/script_pack.tf"; then
  echo "FAIL: pack ensure must materialize tarball from synced env (cdkbot-pack-ensure-shell)" >&2
  exit 1
fi

if grep -v 'never.*export WORK_ROOT' "${ROOT}/spawn_contracts.tf" | grep -qE 'export WORK_ROOT='; then
  echo "FAIL: spawn_contracts.tf must not use export WORK_ROOT= in execute_series (Guild blocks export — trace 2f0357dbee47)" >&2
  exit 1
fi

if ! grep -q 'progress-comment.sh' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn context must invoke progress-comment.sh from pack (no inline CDKBOT_PROGRESS heredoc)" >&2
  exit 1
fi

if ! grep -q 'Subprocess env (trace eed7f3b6)' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must document subprocess env prefix rule (trace eed7f3b6)" >&2
  exit 1
fi

if ! grep -q 'CDKBOT_ALLOW_DIRECT=1;' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn one-liners must use CDKBOT_ALLOW_DIRECT=1; before pack ensure" >&2
  exit 1
fi

if grep -E 'CDKBOT_ALLOW_DIRECT=1 \$\{local\.cdkbot_pack_ensure_shell\}' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn must not prefix env vars only on pack ensure (use CDKBOT_ALLOW_DIRECT=1; before ensure)" >&2
  exit 1
fi

if [ ! -f "${ROOT}/scripts/progress-comment.sh" ]; then
  echo "FAIL: missing scripts/progress-comment.sh" >&2
  exit 1
fi

if ! grep -q "CDKBOT_CLONE_EXECUTE" "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: clone template must wrap script in /bin/bash <<'CDKBOT_CLONE_EXECUTE' heredoc" >&2
  exit 1
fi

if ! grep -q 'environment enumeration' "${MAIN}"; then
  echo "FAIL: clone-blocked-gate must match environment enumeration shell blocks" >&2
  exit 1
fi

if ! grep -q 'auto_approve_integration_tools' "${ROOT}/variables.tf"; then
  echo "FAIL: variables.tf missing auto_approve_integration_tools" >&2
  exit 1
fi

if ! grep -q 'integration_auto_approve_tool_patterns' "${MAIN}"; then
  echo "FAIL: main.tf missing integration_auto_approve_tool_patterns for HITL bypass" >&2
  exit 1
fi

if ! grep -q 'sub_agent_name = "implement-cdk-resolve-paths"' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts.tf missing implement-cdk-resolve-paths" >&2
  exit 1
fi

if ! grep -q 'sub_agent_name = "implement-cdk-app-update"' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts.tf missing implement-cdk-app-update" >&2
  exit 1
fi

if ! grep -q 'cdk_spawn_context_implement_app' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts.tf missing cdk_spawn_context_implement_app" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-cdk-app-update"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'implement-app-run'; then
  echo "FAIL: implement-cdk-app-update spawn context must invoke implement-app-run" >&2
  exit 1
fi

if awk '/sub_agent_name = "implement-cdk-app-update"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -qE '<shell edits|<one-line summary>'; then
  echo "FAIL: implement-app spawn context must not contain angle-bracket copy-paste placeholders (trace fd3d69cf)" >&2
  exit 1
fi

implement_app_spawn_ctx="$(grep -A35 'cdk_spawn_context_implement_app = ' "${ROOT}/spawn_contracts.tf" || true)"

if ! grep -q 'prepare-implement-edits' <<<"${implement_app_spawn_ctx}"; then
  echo "FAIL: implement-app spawn context must use prepare-implement-edits for series 1 (trace f481e55e)" >&2
  exit 1
fi

if grep -q "CDKBOT_IMPLEMENT_EDITS" <<<"${implement_app_spawn_ctx}"; then
  echo "FAIL: implement-app series 1 must not use inline heredoc (trace f481e55e/84fa1c68)" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-cdk-app-update"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'create_files'; then
  echo "FAIL: implement-cdk-app-update must include create_files for edit script (series 1 hardening)" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-cdk-app-update"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'f481e55e'; then
  echo "FAIL: implement-cdk-app-update must document heredoc failure trace f481e55e" >&2
  exit 1
fi

if ! grep -q 'EXACTLY TWO execute_series' <<<"${implement_app_spawn_ctx}"; then
  echo "FAIL: implement-app spawn context must document two-series write-then-run flow" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-cdk-app-update"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'fd3d69cf'; then
  echo "FAIL: implement-cdk-app-update must document angle-bracket shell syntax failure (trace fd3d69cf)" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-cdk-app-update"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '933de8722d8d'; then
  echo "FAIL: implement-cdk-app-update must document rg-on-issue-body failure (trace 933de8722d8d)" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-cdk-app-update"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'ask_clarifying_question'; then
  echo "FAIL: implement-cdk-app-update must forbid ask_clarifying_question (webhook has issue_details)" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-cdk-app-update"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'no_file_edits'; then
  echo "FAIL: implement-cdk-app-update must handle implement_blocker=no_file_edits without asking user" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-cdk-app-update"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'f7a79c2a'; then
  echo "FAIL: implement-cdk-app-update must document malformed edit script failure (trace f7a79c2a)" >&2
  exit 1
fi

if ! grep -q 'webhook JSON already has title/body' "${ROOT}/templates/stage-notes/edit.md.tftpl"; then
  echo "FAIL: implement-cdk stage notes must forbid asking operator when webhook has issue body" >&2
  exit 1
fi

if ! grep -q 'stage_summary:clone' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: progress spawn contract must use stage_summary:clone" >&2
  exit 1
fi

default_quality_iters="$(awk '/variable "module_quality_max_iterations"/,/^}/' "${ROOT}/variables.tf" | awk '/default[[:space:]]*=/ {print; exit}')"
if ! echo "${default_quality_iters}" | grep -q 'default[[:space:]]*=[[:space:]]*1'; then
  echo "FAIL: module_quality_max_iterations default must be 1 (Guild visit cap 5)" >&2
  exit 1
fi

if ! grep -q 'planner_min_tool_calls' "${MAIN}"; then
  echo "FAIL: cdk-app-update workflow metadata must set planner_min_tool_calls" >&2
  exit 1
fi

if ! grep -q 'intake_plan_only' "${MAIN}"; then
  echo "FAIL: clone-blocked-gate must match intake_plan_only / plan-only intake" >&2
  exit 1
fi

if ! grep -q 'repo_kind=cdk_app' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner resolve-paths must emit repo_kind=cdk_app for cdk.json repos" >&2
  exit 1
fi

if ! grep -q 'repo_kind=cdk_app' "${ROOT}/templates/cdk-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP must document CDK app routing (repo_kind=cdk_app)" >&2
  exit 1
fi

if ! grep -Fq 'cdkbot_pack_dir}/stage-runner.sh catalog-scaffold' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: catalog scaffold command must invoke \${cdkbot_pack_dir}/stage-runner.sh catalog-scaffold" >&2
  exit 1
fi

if awk '/^Discovery command/,/^Optional overrides/' "${ROOT}/spawn_contracts.tf" | grep -q '\$WORK_ROOT/.pack/stage-runner'; then
  echo "FAIL: discovery command line must not use \$WORK_ROOT/.pack/stage-runner.sh (exit 127 when WORK_ROOT is literal \$HOME)" >&2
  exit 1
fi

if ! grep -q 'Template J' "${ROOT}/templates/cdk-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP must define Template J for quality-loop rework" >&2
  exit 1
fi

if ! grep -q 'Planner stay-on-track' "${ROOT}/templates/cdk-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP must include §5i planner stay-on-track rules" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-cdk-catalog-scaffold"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'module_quality_rework=true'; then
  echo "FAIL: catalog-scaffold spawn goal must document quality-loop rework path" >&2
  exit 1
fi

if ! grep -q 'implement-cdk-catalog-scaffold' "${ROOT}/templates/cdk-bot-orchestration-extensions.md.tftpl"; then
  echo "FAIL: stage-boundary table must list implement-cdk-catalog-scaffold for discovery" >&2
  exit 1
fi

doc_globs=(
  "${ROOT}/templates"
  "${ROOT}/personas"
  "${ROOT}/main.tf"
  "${ROOT}/variables.tf"
)
for path in "${doc_globs[@]}"; do
  if grep -rq 'create_agent' "$path" 2>/dev/null; then
    echo "FAIL: module docs must not reference Guild-internal create_agent tool:" >&2
    grep -rn 'create_agent' "$path" >&2 || true
    exit 1
  fi
done

for note_tpl in clone edit validate; do
  note_bytes="$(wc -c < "${STAGE_NOTES}/${note_tpl}.md.tftpl" | tr -d ' ')"
  if [ "$note_bytes" -gt 4500 ]; then
    echo "FAIL: stage note ${note_tpl}.md.tftpl too large (${note_bytes} bytes) — keep compact; full rules belong in runbook_refs" >&2
    exit 1
  fi
done

echo "OK: workflow structure checks passed"
