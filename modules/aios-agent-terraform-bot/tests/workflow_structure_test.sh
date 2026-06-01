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
  validate-greenfield-skip-gate
  validate-and-test
  validate-infra-gate
  validate-draft-pr-gate
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

if ! grep -q 'mock_provider' "${ROOT}/templates/discovery-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold template must require mock_provider in basic.tftest.hcl" >&2
  exit 1
fi

if ! grep -q 'clone_blocker=(auth|auth_or_network|network|404|branch|placeholder_url|missing_clone_params|repo_not_found_or_auth|missing_script_pack|wrong_shell_dollar_escape)' "${MAIN}"; then
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

if ! grep -q 'stage_runner_path' "${ROOT}/templates/workflow-script-pack.md.tftpl"; then
  echo "FAIL: workflow-script-pack must document stage_runner_path materialization" >&2
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

if grep -q '^---BEGIN CLONE_EXECUTE_SERIES---' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not embed full clone body (causes LLM truncation); use CLONE_ONE_LINER header only" >&2
  exit 1
fi

if grep -qE '^CLONE_ONE_LINER:' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not expose CLONE_ONE_LINER header (agents truncate base64); use TFBOT_PACK_DIR/clone-pack.sh" >&2
  exit 1
fi

if ! grep -q 'tfbot_pack_dir' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn context must expose TFBOT_PACK_DIR / tfbot_pack_dir for clone-pack.sh" >&2
  exit 1
fi

if ! grep -q 'clone-pack.sh clone' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: clone spawn context must document clone-pack.sh clone command" >&2
  exit 1
fi

if ! grep -q 'tfbot_pack_ensure_shell' "${ROOT}/main.tf"; then
  echo "FAIL: main.tf must define tfbot_pack_ensure_shell inline ensure (no PATH dependency)" >&2
  exit 1
fi

if grep -q '\$\$PD' "${ROOT}/main.tf" || grep -q '\$\$TFBOT' "${ROOT}/main.tf"; then
  echo "FAIL: tfbot_pack_ensure_shell must use heredoc single \$ (not \$\$PD/\$\$TFBOT — bash PID expansion in agent commands)" >&2
  exit 1
fi

if ! grep -q 'ubuntu_execute_series_shell_dollar_rule' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must document single-\$ rule for Ubuntu execute_series" >&2
  exit 1
fi

if ! grep -q 'wrong_shell_dollar_escape' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must distinguish wrong_shell_dollar_escape from missing_script_pack" >&2
  exit 1
fi

if ! grep -q 'tfbot_pack_ensure_shell' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: clone spawn must use tfbot_pack_ensure_shell before clone-pack.sh" >&2
  exit 1
fi

if ! grep -q 'TFBOT_CLONE_PACK_B64' "${MAIN}"; then
  echo "FAIL: ubuntu integration must set TFBOT_CLONE_PACK_B64 for pre_launch pack install" >&2
  exit 1
fi

if ! grep -q 'clone-execute-series-embedded.sh.tftpl' "${ROOT}/main.tf"; then
  echo "FAIL: main.tf must wire clone-execute-series-embedded template" >&2
  exit 1
fi

if ! grep -q 'stage-runner.sh validate-and-pr' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts validate context must use short validate-and-pr command" >&2
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

if ! grep -q 'BEGIN COMMIT_PR_EXECUTE_SERIES' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must embed commit-pr body between BEGIN/END COMMIT_PR_EXECUTE_SERIES markers" >&2
  exit 1
fi

if grep -q '^---BEGIN DISCOVERY_SCAFFOLD_EXECUTE_SERIES---' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not embed full discovery body (causes TRIGGER_JSON inline + LLM truncation)" >&2
  exit 1
fi

if ! grep -q 'discovery-scaffold' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: discovery spawn must use stage-runner discovery-scaffold command" >&2
  exit 1
fi

if ! grep -q 'TRIGGER_JSON_B64' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: discovery spawn must use TRIGGER_JSON_B64 not inline TRIGGER_JSON" >&2
  exit 1
fi

if ! grep -q 'terraform_spawn_context_validate' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must define per-stage terraform_spawn_context_validate" >&2
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

if ! grep -q "bin/bash <<'TFBOT_DISCOVERY_SCAFFOLD'" "${ROOT}/templates/discovery-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold embedded template must self-wrap in /bin/bash heredoc" >&2
  exit 1
fi

if ! grep -q 'validate-draft-pr-gate' "${MAIN}"; then
  echo "FAIL: main.tf missing validate-draft-pr-gate conditional_skip" >&2
  exit 1
fi

if ! grep -q 'pr_draft' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must emit pr_draft and use gh pr create --draft on quality failures" >&2
  exit 1
fi

if ! grep -q 'validate-and-pr' "${ROOT}/templates/validate-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: validate template must delegate PR policy to validate-and-pr" >&2
  exit 1
fi

if awk '/sub_agent_name = "validate-and-test-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '"load_skill"'; then
  echo "FAIL: validate-and-test-runner must not include load_skill" >&2
  exit 1
fi

if awk '/sub_agent_name = "implement-module-discovery-scaffold"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '"load_skill"'; then
  echo "FAIL: implement-module-discovery-scaffold must not include load_skill" >&2
  exit 1
fi

if awk '/sub_agent_name = "create-pr-runner"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q '"load_skill"'; then
  echo "FAIL: create-pr-runner spawn contract must not include load_skill" >&2
  exit 1
fi

if ! grep -q 'discovery_greenfield_validated=true' "${ROOT}/templates/discovery-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold template must run inline validate and emit discovery_greenfield_validated=true" >&2
  exit 1
fi

if ! grep -q 'validate-greenfield-skip-gate' "${MAIN}"; then
  echo "FAIL: main.tf missing validate-greenfield-skip-gate conditional_skip" >&2
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

if ! grep -q 'discovery-scaffold' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must implement discovery-scaffold command" >&2
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
if ! grep -q 'validate-and-pr' "${ROOT}/templates/validate-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: validate embed must delegate to validate-and-pr (single PR policy)" >&2
  exit 1
fi
if grep -q 'should_open_pr=' "${ROOT}/templates/validate-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: validate embed must not duplicate PR policy (use validate-and-pr)" >&2
  exit 1
fi

if ! grep -q 'WORK_ROOT:?export WORK_ROOT before discovery scaffold' "${ROOT}/templates/discovery-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold must require WORK_ROOT env for one-liner delivery" >&2
  exit 1
fi

if ! grep -q 'WORK_ROOT:?export WORK_ROOT before clone one-liner' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: clone execute_series must require WORK_ROOT env for one-liner delivery" >&2
  exit 1
fi

if grep -q 'WORK_ROOT="{{work_root}}"' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: clone template must not bake {{work_root}} into base64 blob" >&2
  exit 1
fi

if grep -qE 'sed.*GIT_(USERNAME|TOKEN)|sed -E.*x-access-token' "${ROOT}/templates/terraform-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP must not document sed-based auth clone URLs" >&2
  exit 1
fi

greenfield_skip_match="$(grep -F 'discovery_greenfield_validated[^\\n]{0,48}true.*module_quality_summary[^\\n]{0,48}PASS' "${MAIN}" || true)"
if [ -z "$greenfield_skip_match" ]; then
  echo "FAIL: validate-greenfield-skip-gate must match discovery_greenfield_validated + module_quality_summary PASS (JSON or sentinel)" >&2
  exit 1
fi

if grep -q '(?m)^\\\\s\*module_quality_summary' "${MAIN}"; then
  echo "FAIL: validate-infra-gate must not use line-anchored BLOCKED regex (tables break match)" >&2
  exit 1
fi

draft_gate_match="$(awk '/stage_id[[:space:]]*=[[:space:]]*"validate-draft-pr-gate"/{found=1} found && /match[[:space:]]*=/ {print; exit}' "${MAIN}")"
if [ -z "$draft_gate_match" ]; then
  echo "FAIL: could not find validate-draft-pr-gate match regex in main.tf" >&2
  exit 1
fi
if grep -q 'pr_draft=true' <<<"$draft_gate_match"; then
  echo "FAIL: validate-draft-pr-gate must require pr_url= (not bare pr_draft=true)" >&2
  exit 1
fi
if ! grep -q 'pr_eligible_fmt_validate' "${MAIN}"; then
  echo "FAIL: validate-draft-pr-gate (default) must skip loop on pr_eligible_fmt_validate=true" >&2
  exit 1
fi
if ! grep -q 'continue_quality_loop_after_draft_pr' "${ROOT}/variables.tf"; then
  echo "FAIL: variables.tf must define continue_quality_loop_after_draft_pr" >&2
  exit 1
fi
if ! grep -q 'GitHub issue comment' "${MAIN}"; then
  echo "FAIL: create-pr note must document comment-only path when pr_url is set" >&2
  exit 1
fi
if ! grep -q 'note_val.*working_branch' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: commit-pr must reuse working_branch from notes" >&2
  exit 1
fi

loop_exit_match="$(awk '/stage_id[[:space:]]*=[[:space:]]*"validate-loop-gate"/{found=1} found && /exit_match[[:space:]]*=/ {print; exit}' "${MAIN}")"
if [ -z "$loop_exit_match" ]; then
  echo "FAIL: could not find validate-loop-gate exit_match in main.tf" >&2
  exit 1
fi
if ! grep -qF 'module_quality_summary[^\\n]{0,48}(PASS|BLOCKED)' <<<"$loop_exit_match"; then
  echo "FAIL: validate-loop-gate must exit on BLOCKED as well as PASS (JSON or sentinel summaries)" >&2
  exit 1
fi

if ! grep -q 'script_runner_max_llm_calls     = 8' "${MAIN}"; then
  echo "FAIL: script_runner_max_llm_calls default must be 8" >&2
  exit 1
fi

if ! grep -q 'validate_runner_max_llm_calls   = 12' "${MAIN}"; then
  echo "FAIL: validate_runner_max_llm_calls default must be 12" >&2
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

if ! grep -q 'github_notify_max_llm_calls     = 5' "${MAIN}"; then
  echo "FAIL: github_notify_max_llm_calls default must be 5" >&2
  exit 1
fi

if ! grep -q 'hcl_author_max_llm_calls        = 20' "${MAIN}"; then
  echo "FAIL: hcl_author_max_llm_calls default must be 20" >&2
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

if ! grep -q 'max iterations reached' "${MAIN}"; then
  echo "FAIL: create-pr stage note must document max-iter vs 3b precedence" >&2
  exit 1
fi

if ! grep -q 'script_pack_runner_b64' "${ROOT}/templates/validate-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: validate template must materialize stage-runner from base64 script pack" >&2
  exit 1
fi

if ! grep -q 'script_pack_runner_b64' "${ROOT}/templates/discovery-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold template must materialize stage-runner from base64 script pack" >&2
  exit 1
fi

if ! grep -q 'scaffold_error=invalid_json' "${ROOT}/templates/discovery-scaffold-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: discovery scaffold must validate variables.tf.json before validate" >&2
  exit 1
fi

if ! grep -q 'tfsec_pid' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner validate must run tfsec and checkov in parallel" >&2
  exit 1
fi

default_defer="$(awk '/variable "defer_pr_until_quality_pass"/,/^}/' "${ROOT}/variables.tf" | awk '/default[[:space:]]*=/ {print; exit}')"
if ! grep -q 'default[[:space:]]*=[[:space:]]*true' <<<"$default_defer"; then
  echo "FAIL: defer_pr_until_quality_pass default must be true" >&2
  exit 1
fi

if ! grep -q 'clone_blocker=placeholder_url' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: clone template must emit clone_blocker=placeholder_url for invented URLs" >&2
  exit 1
fi

if ! grep -q 'execute_series_working_dir' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn context must expose execute_series_working_dir for Ubuntu execute_series" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "check-info-and-clone-clone"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'ubuntu_execute_series_working_dir_rule'; then
  echo "FAIL: clone spawn contract must forbid WORK_ROOT as execute_series working_dir" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "check-info-and-clone-clone"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'REPO_CLONE_URL='; then
  echo "FAIL: clone spawn contract must require discrete REPO_CLONE_URL export (not inline TRIGGER_JSON)" >&2
  exit 1
fi

if awk '/sub_agent_name = "check-info-and-clone-clone"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -qE "When notes empty export TRIGGER_JSON='|export WORK_ROOT='[^']+' TRIGGER_JSON='\\{"; then
  echo "FAIL: clone spawn contract must not instruct inline TRIGGER_JSON in shell command" >&2
  exit 1
fi

if awk '/sub_agent_name = "check-info-and-clone-clone"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -qE 'paste CLONE_ONE_LINER|&& CLONE_ONE_LINER|CLONE_ONE_LINER from'; then
  echo "FAIL: clone spawn contract goal must not instruct pasting CLONE_ONE_LINER" >&2
  exit 1
fi

if ! grep -q '9d8958e4' "${MAIN}"; then
  echo "FAIL: check-info-and-clone stage note should reference trace 9d8958e4 clone-order fix" >&2
  exit 1
fi

pack_main="$(grep -E 'script_pack_version[[:space:]]*=' "${MAIN}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
clone_ver="$(grep 'script_pack_version=' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl" | head -1 | sed -E 's/.*=\$\{script_pack_version\}|.*=\$\{([^}]+)\}.*/\1/')"
if [ "$clone_ver" = "script_pack_version" ]; then
  clone_ver="$(grep 'script_pack_version=' "${ROOT}/templates/clone-execute-series-embedded.sh.tftpl" | tail -1 | sed -E 's/.*\$\{([^}]+)\}.*/\1/')"
fi
if [ "$pack_main" != "20260531.37" ]; then
  echo "FAIL: expected script_pack_version 20260531.37 in main.tf (got ${pack_main})" >&2
  exit 1
fi

if ! awk '/terraform_spawn_context_discovery_scaffold/,/^  terraform_spawn_context =/' "${ROOT}/spawn_contracts.tf" | grep -q 'tfbot_pack_dir}/stage-runner.sh discovery-scaffold'; then
  echo "FAIL: discovery command must invoke \${tfbot_pack_dir}/stage-runner.sh (pack path, not \$WORK_ROOT/.pack)" >&2
  exit 1
fi

if awk '/^Discovery command/,/^Optional overrides/' "${ROOT}/spawn_contracts.tf" | grep -q '\$WORK_ROOT/.pack/stage-runner'; then
  echo "FAIL: discovery command line must not use \$WORK_ROOT/.pack/stage-runner.sh (exit 127 when WORK_ROOT is literal \$HOME)" >&2
  exit 1
fi

if ! grep -q 'Template J' "${ROOT}/templates/terraform-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP must define Template J for quality-loop rework" >&2
  exit 1
fi

if ! grep -q 'Planner stay-on-track' "${ROOT}/templates/terraform-bot-orchestration-sop.md.tftpl"; then
  echo "FAIL: orchestration SOP must include §5i planner stay-on-track rules" >&2
  exit 1
fi

if ! awk '/sub_agent_name = "implement-module-discovery-scaffold"/,/^    },/' "${ROOT}/spawn_contracts.tf" | grep -q 'module_quality_rework=true'; then
  echo "FAIL: discovery-scaffold spawn goal must document quality-loop rework path" >&2
  exit 1
fi

if ! grep -q 'implement-module-scaffold.*discovery_repo=true' "${ROOT}/templates/terraform-bot-orchestration-extensions.md.tftpl"; then
  echo "FAIL: stage-boundary table must forbid implement-module-scaffold when discovery_repo=true" >&2
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

echo "OK: workflow structure checks passed"
