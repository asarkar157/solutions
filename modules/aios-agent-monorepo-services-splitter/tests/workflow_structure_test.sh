#!/usr/bin/env bash
# Static checks for monorepo-services-splitter workflows in main.tf.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"

if [ -f "${ROOT}/templates/db-state-split-orchestration.md.tftpl" ]; then
  echo "FAIL: remove templates/db-state-split-orchestration.md.tftpl — use monorepo-split-orchestration.md.tftpl (db-state SOP belongs in aios-agent-db-state-splitter)" >&2
  exit 1
fi

if ! grep -q 'subagent_task_type[[:space:]]*=[[:space:]]*var.subagent_task_type' "${MAIN}"; then
  echo "FAIL: template_vars must pass subagent_task_type for SOP templates" >&2
  exit 1
fi

if ! grep -q 'CCE_LENS_USE_CASES' "${MAIN}"; then
  echo "FAIL: main.tf must set CCE_LENS_USE_CASES on Ubuntu/runner env" >&2
  exit 1
fi

if ! grep -q 'cce_lens_use_cases' "${ROOT}/variables.tf"; then
  echo "FAIL: variables.tf must define cce_lens_use_cases" >&2
  exit 1
fi

if ! grep -q 'platform-adoption' "${ROOT}/variables.tf"; then
  echo "FAIL: cce_recipes default must include platform-adoption (catalog recipe)" >&2
  exit 1
fi

if grep -q 'monorepo-intelligence' "${ROOT}/variables.tf" && grep 'cce_recipes' "${ROOT}/variables.tf" | grep -q 'monorepo-intelligence'; then
  echo "FAIL: monorepo-intelligence must not be in cce_recipes (lens-only; use cce_lens_use_cases)" >&2
  exit 1
fi

analysis_stages=(
  clone-and-boundary-scan
  scan-blocked-gate
  llm-analysis-skip-gate
  analyze-coupling-and-contexts
  parallel-plan-prep
  plan-fan-in-gate
  plan-validation-gate
  llm-plan-review
  os-enrichment-skip-gate
  llm-os-enrichment
  targeted-cce-skip-gate
  targeted-cce-rescan
  open-guidance-pr
  final-evidence-gate
)

extract_stages=(
  load-approved-plan
  plan-blocked-gate
  scaffold-service-layout
  cursor-skip-gate
  cursor-refactor-services
  open-extract-pr
  extract-evidence-gate
)

for stage in "${analysis_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing analysis stage_id ${stage} in main.tf" >&2
    exit 1
  fi
done

for stage in "${extract_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing extract stage_id ${stage} in main.tf" >&2
    exit 1
  fi
done

if ! grep -q 'action_type[[:space:]]*=[[:space:]]*"conditional_skip"' "${MAIN}"; then
  echo "FAIL: workflow must define conditional_skip gates" >&2
  exit 1
fi

if ! grep -q 'blocked:missing_plan_artifact' "${MAIN}"; then
  echo "FAIL: extract workflow must reference blocked:missing_plan_artifact sentinel" >&2
  exit 1
fi

if ! grep -q 'plan-blocked-gate' "${MAIN}"; then
  echo "FAIL: extract workflow must define plan-blocked-gate conditional_skip" >&2
  exit 1
fi

if ! grep -q 'skip_to[[:space:]]*=[[:space:]]*"extract-evidence-gate"' "${MAIN}"; then
  echo "FAIL: plan-blocked-gate must skip to extract-evidence-gate" >&2
  exit 1
fi

if ! grep -q 'split-load-approved-plan-sop' "${MAIN}"; then
  echo "FAIL: load-approved-plan must use split-load-approved-plan-sop" >&2
  exit 1
fi

if ! grep -q 'NO create_agent' "${MAIN}"; then
  echo "FAIL: load-approved-plan note must forbid create_agent / Ubuntu runners" >&2
  exit 1
fi

if ! grep -q 'scaffold_layout_validated' "${ROOT}/scripts/scaffold-services.sh"; then
  echo "FAIL: scaffold-services must set scaffold_layout_validated" >&2
  exit 1
fi

if ! grep -q 'render-pr-body' "${ROOT}/scripts/clone-and-pr.sh"; then
  echo "FAIL: clone-and-pr must generate PR body from diff" >&2
  exit 1
fi

if ! grep -q 'ensure_repo_cloned' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must clone repo for extract scaffold" >&2
  exit 1
fi

if ! grep -q 'NEVER gh pr create' "${MAIN}"; then
  echo "FAIL: scaffold stage must forbid gh pr create in note" >&2
  exit 1
fi

if ! grep -q 'blocked:missing_github_repo_url' "${MAIN}"; then
  echo "FAIL: analysis must reference blocked:missing_github_repo_url sentinel" >&2
  exit 1
fi

if ! grep -q 'clone-and-boundary-scan-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must register clone-and-boundary-scan-runner" >&2
  exit 1
fi

if ! grep -q 'guidance-pr-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must register guidance-pr-runner" >&2
  exit 1
fi

if ! grep -q 'scaffold-services-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must register scaffold-services-runner" >&2
  exit 1
fi

if ! grep -q 'extract-pr-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must register extract-pr-runner" >&2
  exit 1
fi

if ! grep -q 'cmd_clone_and_scan' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must include clone-and-scan command" >&2
  exit 1
fi

if ! grep -q 'cmd_guidance_pr' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must include guidance-pr command" >&2
  exit 1
fi

if ! grep -q 'cmd_scaffold_services' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must include scaffold-services command" >&2
  exit 1
fi

if ! grep -q 'MONOREPO_SPLIT_EMBEDDED' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must require MONOREPO_SPLIT_EMBEDDED invocation" >&2
  exit 1
fi

if ! grep -q 'MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2' "${MAIN}"; then
  echo "FAIL: ubuntu integration env_vars must set MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2" >&2
  exit 1
fi

if grep -q 'MONOSPLIT_B64=' "${MAIN}"; then
  echo "FAIL: decode commands must not assign inline MONOSPLIT_B64= (B64 belongs on Ubuntu integration env)" >&2
  exit 1
fi

if grep -q "printf '%s' '\${local.monosplit_" "${MAIN}"; then
  echo "FAIL: decode commands must not wrap B64 in single quotes" >&2
  exit 1
fi

if ! grep -q 'monosplit_b64_decode_suffix' "${MAIN}"; then
  echo "FAIL: decode commands must use shared monosplit_b64_decode_suffix local" >&2
  exit 1
fi

if ! grep -q 'printf %s' "${MAIN}"; then
  echo "FAIL: decode commands must read integration B64 via printf %s" >&2
  exit 1
fi

if ! grep -q 'base64 -d | bash' "${MAIN}"; then
  echo "FAIL: decode commands must pipe base64 -d to bash" >&2
  exit 1
fi

if ! grep -q 'targeted-cce-scan-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must register targeted-cce-scan-runner" >&2
  exit 1
fi

if ! grep -q 'monorepo-cce-scan.sh' "${ROOT}/scripts/boundary-scan.sh"; then
  echo "FAIL: boundary-scan must invoke monorepo-cce-scan.sh" >&2
  exit 1
fi

if ! grep -q 'module "cce_scripts"' "${MAIN}"; then
  echo "FAIL: main.tf must wire aios-cce-scripts module" >&2
  exit 1
fi

if ! grep -q 'cmd_targeted_cce_scan' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must include targeted-cce-scan command" >&2
  exit 1
fi

if ! grep -A40 'env_vars = merge' "${MAIN}" | grep -q 'MONOSPLIT_SCAN_EXECUTE_SERIES_B64_V2'; then
  echo "FAIL: ubuntu integration env_vars must set MONOSPLIT_*_EXECUTE_SERIES_B64_V2" >&2
  exit 1
fi

if ! grep -q 'ubuntu_execute_series_shell_dollar_rule' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must document single-\$ shell rule (PID expansion)" >&2
  exit 1
fi

if grep -q '_create_files"' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not allow create_files on embed runners (use spawn context inline bootstrap)" >&2
  exit 1
fi

if grep -E '_execute_command"' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not allow execute_command on runners" >&2
  exit 1
fi

if grep -q 'base64encode(' "${MAIN}"; then
  : # spawn-context B64 locals are required
fi

if grep -q 'monosplit-scan-embed.b64' "${MAIN}"; then
  echo "FAIL: decode commands must not read embed .b64 files" >&2
  exit 1
fi

if ! grep -q 'scan_blocked_gate_match_regex' "${MAIN}"; then
  echo "FAIL: scan-blocked-gate must use line-anchored scan_blocked_gate_match_regex local" >&2
  exit 1
fi

if ! grep -q 'workflow_execution_metadata' "${MAIN}"; then
  echo "FAIL: main.tf must define workflow_execution_metadata local" >&2
  exit 1
fi

if ! grep -q 'halguard_skip_subagent_task_types' "${MAIN}"; then
  echo "FAIL: workflow metadata must include halguard_skip_subagent_task_types" >&2
  exit 1
fi

if ! grep -q 'terminal_calling_halguard_mode' "${MAIN}"; then
  echo "FAIL: workflow metadata must include terminal_calling_halguard_mode" >&2
  exit 1
fi

if ! grep -q 'HALGUARD: workflow metadata halguard_skip_subagent_task_types=terminal_calling' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must document HalGuard metadata for terminal runners" >&2
  exit 1
fi

if ! grep -q 'archive_file.monosplit_script_pack' "${MAIN}"; then
  echo "FAIL: main.tf must tarball script pack via archive_file at tofu apply" >&2
  exit 1
fi

if ! grep -q 'MONOSPLIT_SCRIPT_PACK_TARBALL_B64' "${MAIN}"; then
  echo "FAIL: ubuntu env_vars must set MONOSPLIT_SCRIPT_PACK_TARBALL_B64" >&2
  exit 1
fi

if ! grep -q 'monosplit_install_script_pack_body' "${MAIN}"; then
  echo "FAIL: main.tf must render monosplit_install_script_pack_body" >&2
  exit 1
fi

if ! grep -q 'monosplit-install-script-pack.sh.tftpl' "${MAIN}"; then
  echo "FAIL: main.tf must use monosplit-install-script-pack.sh.tftpl" >&2
  exit 1
fi

if grep -q 'monosplit-fetch-script-pack.sh.tftpl' "${MAIN}"; then
  echo "FAIL: main.tf must not reference runtime git fetch template" >&2
  exit 1
fi

if ! grep -q "tr -d" "${MAIN}"; then
  echo "FAIL: decode commands must strip whitespace before base64 -d" >&2
  exit 1
fi

if grep -q 'script_pack_boundary_scan_b64' "${MAIN}"; then
  echo "FAIL: main.tf must not embed nested script_pack_*_b64 in outer bootstrap" >&2
  exit 1
fi

if ! grep -q 'runtime-deps-provision.sh' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must invoke runtime-deps-provision.sh" >&2
  exit 1
fi

if ! grep -q 'runtime_deps_provisioned' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must document runtime_deps_provisioned notes" >&2
  exit 1
fi

if ! grep -q 'agents-md-scaffold.sh' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must install agents-md-scaffold.sh" >&2
  exit 1
fi

if ! grep -q 'cmd_write_guidance_artifacts' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must include guidance artifacts writer (AGENTS.md)" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_parallel_plan_prep' "${MAIN}"; then
  echo "FAIL: main.tf must define spawn_contracts_parallel_plan_prep" >&2
  exit 1
fi

if ! grep -q 'synthesize-split-plan-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must include synthesize-split-plan-runner" >&2
  exit 1
fi

if ! grep -q 'is_placeholder_service_catalog' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must block placeholder service catalog" >&2
  exit 1
fi

if ! grep -q 'deterministic_plan_produced' "${ROOT}/scripts/synthesize-split-plan.sh"; then
  echo "FAIL: synthesize-split-plan.sh must emit deterministic_plan_produced" >&2
  exit 1
fi

if ! grep -q 'agents_md_produced' "${MAIN}"; then
  echo "FAIL: final evidence must track agents_md_produced" >&2
  exit 1
fi

if ! grep -q 'split_mode=scaffold_only' "${MAIN}"; then
  echo "FAIL: extract workflow must skip Cursor when split_mode=scaffold_only" >&2
  exit 1
fi

if ! grep -q 'enable_cursor_integration' "${ROOT}/variables.tf"; then
  echo "FAIL: missing enable_cursor_integration variable" >&2
  exit 1
fi

if ! grep -q 'sg_agent.*cursor_split_executor' "${MAIN}"; then
  echo "FAIL: main.tf must define cursor_split_executor agent" >&2
  exit 1
fi

if ! grep -q '\$HOME/.<workflow_run_id>/' "${MAIN}"; then
  echo "FAIL: scratch paths must use workflow_run_id disk mirror" >&2
  exit 1
fi

if grep -RinE 'must recycle|docker rm -f guild-integration|recycle sidecar|reprovision sidecar|re-inject MONOSPLIT|Re-apply Tofu to re-inject' \
  "${ROOT}/templates" "${ROOT}/personas" "${MAIN}" 2>/dev/null \
  | grep -vE 'FORBIDDEN|Never instruct|never tell|Forbidden|do not tell|Do not discuss|must not'; then
  echo "FAIL: runbooks must not instruct integration container lifecycle or manual B64 re-inject" >&2
  exit 1
fi

if grep -Rin 'sidecar' "${ROOT}/templates" "${ROOT}/personas" "${ROOT}/spawn_contracts.tf" "${MAIN}" 2>/dev/null; then
  echo "FAIL: workflow-facing text must not use sidecar terminology" >&2
  exit 1
fi

if grep -q 'monosplit-work' "${ROOT}/templates/monosplit-resolve-env.sh.tftpl"; then
  echo "FAIL: resolve-env must not fall back to shared .monosplit-work path" >&2
  exit 1
fi

if ! grep -q 'ubuntu_shared_integration_rule' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must document shared Ubuntu integration isolation" >&2
  exit 1
fi

pack_main="$(grep -E 'script_pack_version[[:space:]]*=' "${MAIN}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
pack_runner="$(grep -E '^SCRIPT_PACK_VERSION=' "${ROOT}/scripts/stage-runner.sh" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [ -z "$pack_main" ] || [ -z "$pack_runner" ] || [ "$pack_main" != "$pack_runner" ]; then
  echo "FAIL: script_pack_version mismatch main.tf=${pack_main} stage-runner.sh=${pack_runner}" >&2
  exit 1
fi

if [ ! -f "${ROOT}/policies/monorepo-split-readonly-default.rego" ]; then
  echo "FAIL: missing monorepo-split-readonly-default.rego policy" >&2
  exit 1
fi

template_count="$(find "${ROOT}/templates" -name '*.md.tftpl' | wc -l | tr -d ' ')"
if [ "$template_count" -lt 11 ]; then
  echo "FAIL: expected at least 11 template SOPs, found ${template_count}" >&2
  exit 1
fi

if ! grep -q 'target_pr_repo' "${ROOT}/variables.tf"; then
  echo "FAIL: variables.tf must define target_pr_repo" >&2
  exit 1
fi

if ! grep -q 'build-coupling-matrix.sh' "${ROOT}/scripts/boundary-scan.sh"; then
  echo "FAIL: boundary-scan must invoke build-coupling-matrix.sh" >&2
  exit 1
fi

echo "OK: monorepo-services-splitter workflow structure checks passed"
