#!/usr/bin/env bash
# Static checks for db-monorepo-state-split-convergence workflow in main.tf (lean v2 DAG).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"

required_stages=(
  ingest-and-split
  ingest-blocked-gate
  registry-and-import-codegen
  shell-converge-matrix
  materialize-appstacks-coordinator
  orphans-secondary-pipeline
  final-gate-and-memory
)

for stage in "${required_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing stage_id ${stage} in main.tf" >&2
    exit 1
  fi
done

# Legacy stages must not return.
for legacy in \
  split-input-gate split-loop-gate split-ingest-blocked-gate iac-pr-fast-path-gate \
  hcl-hydrate-per-group materialize-stackgen-appstacks \
  multi-shard-plan-convergence multi-shard-plan-infra-gate multi-shard-plan-loop-gate \
  discover-db-anchors allocate-related-resources count-reconcile-loop count-reconcile-loop-gate ingest-monolith
do
  if grep -q "stage_id[[:space:]]*=[[:space:]]*\"${legacy}\"" "${MAIN}"; then
    echo "FAIL: legacy stage ${legacy} still present" >&2
    exit 1
  fi
done

if grep -q 'action_type[[:space:]]*=[[:space:]]*"loop_stage"' "${MAIN}"; then
  echo "FAIL: v2 DAG must not use loop_stage gates (false GO_BACK fan-in)" >&2
  exit 1
fi

if ! grep -q 'action_type[[:space:]]*=[[:space:]]*"conditional_skip"' "${MAIN}"; then
  echo "FAIL: workflow must define conditional_skip for ingest-blocked-gate" >&2
  exit 1
fi

if ! grep -q 'ingest-blocked-gate' "${MAIN}"; then
  echo "FAIL: missing ingest-blocked-gate conditional_skip" >&2
  exit 1
fi

if ! grep -q 'blocked:missing_monolith_state_uri' "${MAIN}"; then
  echo "FAIL: ingest must emit blocked:missing_monolith_state_uri sentinel" >&2
  exit 1
fi

if ! grep -q 'blocked:remote_runner_tofu_missing' "${MAIN}"; then
  echo "FAIL: workflow must reference blocked:remote_runner_tofu_missing sentinel" >&2
  exit 1
fi

if ! grep -q 'blocked:three_runner_attempts_failed' "${MAIN}"; then
  echo "FAIL: ingest must emit blocked:three_runner_attempts_failed sentinel" >&2
  exit 1
fi

if grep -q '"action":"GO_BACK"' "${MAIN}"; then
  echo "FAIL: v2 DAG must not match GO_BACK in conditional_skip (false fan-in)" >&2
  exit 1
fi

if ! grep -q 'output_matches_regex' "${MAIN}"; then
  echo "FAIL: conditional_skip gates must use output_matches_regex" >&2
  exit 1
fi

if ! grep -q 'cmd_registry_scaffold' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must include registry scaffold command" >&2
  exit 1
fi

if ! grep -q '$HOME/.<workflow_run_id>/' "${MAIN}"; then
  echo "FAIL: scratch paths must use stagerunner workflow_run_id" >&2
  exit 1
fi

if ! grep -q 'appstack-materialize-runner-batch' "${MAIN}"; then
  echo "FAIL: materialize coordinator must mandate parallel appstack batch fan-out" >&2
  exit 1
fi

if ! grep -q 'flow_type:"parallel"' "${MAIN}"; then
  echo "FAIL: parallel batch fan-out must use flow_type parallel" >&2
  exit 1
fi

if ! grep -q 'shell-converge-matrix-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must register shell-converge-matrix-runner" >&2
  exit 1
fi

if ! grep -A20 'appstack-materialize-runner-batch' "${ROOT}/spawn_contracts.tf" | grep -q '_execute_command'; then
  echo "FAIL: appstack batch spawn must include shell execute_command to read batch_payloads.json on runner" >&2
  exit 1
fi

if ! grep -q 'CONVERGE_EXECUTE_SERIES' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must include CONVERGE_EXECUTE_SERIES block" >&2
  exit 1
fi

if ! grep -q 'prepare-parallel-artifacts' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must support prepare-parallel-artifacts command" >&2
  exit 1
fi

if ! grep -q 'hydrate-and-plan-matrix' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must support hydrate-and-plan-matrix command" >&2
  exit 1
fi

if grep -q 'rsync' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must use cp -a only (no rsync dependency)" >&2
  exit 1
fi

if ! grep -q 'tag_seeded_connectivity_capped' "${MAIN}"; then
  echo "FAIL: large-state default must use tag_seeded_connectivity_capped" >&2
  exit 1
fi

if [ ! -f "${ROOT}/scripts/allocate_manifest.py" ]; then
  echo "FAIL: missing scripts/allocate_manifest.py" >&2
  exit 1
fi

if ! grep -q 'DBSPLIT_EMBEDDED' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must require DBSPLIT_EMBEDDED invocation" >&2
  exit 1
fi

if ! grep -q 'merge_small_by_seed' "${ROOT}/scripts/allocate_manifest.py"; then
  echo "FAIL: allocate_manifest.py must include merge_small_by_seed" >&2
  exit 1
fi

if ! grep -q 'stage_depends_on = \["ingest-and-split"\]' "${MAIN}"; then
  echo "FAIL: ingest-blocked-gate must depend on ingest-and-split" >&2
  exit 1
fi

if ! grep -q 'stage_depends_on = \["shell-converge-matrix", "materialize-appstacks-coordinator", "orphans-secondary-pipeline"\]' "${MAIN}"; then
  echo "FAIL: final-gate must fan-in parallel layer" >&2
  exit 1
fi

if ! grep -q 'count_reconciliation_ok: \\\"false\\\"' "${MAIN}"; then
  echo "FAIL: ingest-blocked-gate must match count_reconciliation_ok false" >&2
  exit 1
fi

if ! grep -q 'INGEST STOP RULE' "${MAIN}"; then
  echo "FAIL: ingest stage must define INGEST STOP RULE" >&2
  exit 1
fi

if ! grep -q 'ingest-and-split-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must register ingest-and-split-runner" >&2
  exit 1
fi

if ! grep -q 'working_dir=/' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: ingest runner spawn contract must forbid WORK_ROOT working_dir" >&2
  exit 1
fi

if grep -q 'dbsplit_fetch_script_pack' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest embed must not git-fetch script pack (terraform-baked b64)" >&2
  exit 1
fi

if grep -q "DBSPLIT_INGEST_EXECUTE" "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest embed must be plain bash (no outer heredoc wrapper)" >&2
  exit 1
fi

if ! grep -q 'dbsplit_load_script_pack_env' "${ROOT}/templates/dbsplit-script-pack-env.sh.tftpl"; then
  echo "FAIL: dbsplit-script-pack-env partial must define dbsplit_load_script_pack_env" >&2
  exit 1
fi

if ! grep -q 'dbsplit_script_pack_env_helpers' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest embed must include dbsplit_script_pack_env_helpers partial" >&2
  exit 1
fi

if grep -q 'script_pack_runner_b64' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest embed must not inline terraform script_pack_*_b64 (runner env sync at tofu apply)" >&2
  exit 1
fi

if ! grep -q 'runner_script_pack_env' "${MAIN}"; then
  echo "FAIL: main.tf must provision runner_script_pack_env secret for DBSPLIT_SCRIPT_PACK_* sync" >&2
  exit 1
fi

if ! grep -q 'DBSPLIT_INGEST_BOOTSTRAP_B64' "${MAIN}"; then
  echo "FAIL: runner_script_pack_env JSON must include DBSPLIT_INGEST_BOOTSTRAP_B64" >&2
  exit 1
fi

if ! grep -q 'ingest_bootstrap_execute_command' "${MAIN}"; then
  echo "FAIL: main.tf must define ingest_bootstrap_execute_command" >&2
  exit 1
fi

if grep 'ingest_bootstrap_execute_command' "${MAIN}" | grep -q '<<<'; then
  echo "FAIL: ingest bootstrap command must not use bash <<< (aiden-runner runs sh -c)" >&2
  exit 1
fi

if ! grep -q 'dbsplit_resolve_monolith_uri' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest execute series must resolve MONOLITH_URI deterministically" >&2
  exit 1
fi

if ! grep -q 'dbsplit_resolve_work_root' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest execute series must resolve WORK_ROOT via WORKFLOW_RUN_ID or spawn_monolith_uri" >&2
  exit 1
fi

if ! grep -q 'export WORKFLOW_RUN_ID="{{workflow_run_id}}"' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest embed must export WORKFLOW_RUN_ID from spawn placeholder before resolving WORK_ROOT" >&2
  exit 1
fi

if grep -q '{{workflow_run_id}}' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl" \
  && ! grep -q 'export WORKFLOW_RUN_ID="{{workflow_run_id}}"' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest embed must only use {{workflow_run_id}} for WORKFLOW_RUN_ID export (guild spawn substitution)" >&2
  exit 1
fi

if grep -qE '/\."\$\$\{WORKFLOW_RUN_ID\}' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: WORKFLOW_RUN_ID path must be inside one quoted string (/.\\\${WORKFLOW_RUN_ID})" >&2
  exit 1
fi

if ! grep -q 'spawn_monolith_uri' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: ingest spawn contract must require spawn_monolith_uri pre-write" >&2
  exit 1
fi

if ! grep -q 'INGEST_BOOTSTRAP_EXECUTE_COMMAND' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must deliver ingest via INGEST_BOOTSTRAP_EXECUTE_COMMAND" >&2
  exit 1
fi

if ! grep -q 'INGEST_BOOTSTRAP_SHA256' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must expose INGEST_BOOTSTRAP_SHA256" >&2
  exit 1
fi

if sed -n '/sub_agent_name = "ingest-and-split-runner"/,/^    },/p' "${ROOT}/spawn_contracts.tf" \
  | sed -n '/tool_names = \[/,/\]/p' | grep -q 'execute_series'; then
  echo "FAIL: ingest spawn_contract tool_names must not include execute_series (bootstrap is one execute_command)" >&2
  exit 1
fi

if sed -n '/sub_agent_name = "ingest-and-split-runner"/,/^    },/p' "${ROOT}/spawn_contracts.tf" \
  | sed -n '/tool_names = \[/,/\]/p' | grep -q 'create_files'; then
  echo "FAIL: ingest spawn_contract tool_names must not include create_files" >&2
  exit 1
fi

if ! grep -q 'task_type      = var.subagent_task_type' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must use var.subagent_task_type (default coding) for runner sub-agents" >&2
  exit 1
fi

if ! grep -q 'non_trivial_model_names' "${MAIN}"; then
  echo "FAIL: main.tf must filter efficiency/mini models via non_trivial_model_names" >&2
  exit 1
fi

if grep -q 'INGEST_EXECUTE_SERIES_B64:' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not expose raw INGEST_EXECUTE_SERIES_B64 to the LLM" >&2
  exit 1
fi

if grep -q -e '---BEGIN INGEST_EXECUTE_SERIES---' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not embed raw INGEST heredoc" >&2
  exit 1
fi

if ! grep -q 'INGEST_RUNNER_RULE' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must include INGEST_RUNNER_RULE bootstrap guidance" >&2
  exit 1
fi

if ! grep -q 'DBSPLIT_INGEST_BOOTSTRAP_B64' "${ROOT}/templates/dbsplit-script-pack-env.sh.tftpl"; then
  echo "FAIL: dbsplit-script-pack-env must load DBSPLIT_INGEST_BOOTSTRAP_B64 from secret JSON" >&2
  exit 1
fi

orch="${ROOT}/templates/db-state-split-orchestration.md.tftpl"
if grep -q 'INGEST_EXECUTE_SERIES_B64' "$orch"; then
  echo "FAIL: orchestration SOP must not reference INGEST_EXECUTE_SERIES_B64" >&2
  exit 1
fi
if grep -q 'create_files.*ingest-embed' "$orch"; then
  echo "FAIL: orchestration SOP must not instruct create_files for ingest-embed.b64" >&2
  exit 1
fi
if ! grep -q 'INGEST_BOOTSTRAP_EXECUTE_COMMAND' "$orch"; then
  echo "FAIL: orchestration SOP must document INGEST_BOOTSTRAP_EXECUTE_COMMAND ingest bootstrap" >&2
  exit 1
fi
if ! grep -qi 'shell tools only' "$orch"; then
  echo "FAIL: orchestration SOP must forbid MCP integration execute_* on ingest runner" >&2
  exit 1
fi

if ! grep -q '019e905a51fc' "${MAIN}"; then
  echo "FAIL: ingest stage note must reference trace 019e905a51fc wrong-tool-prefix failure" >&2
  exit 1
fi

if ! grep -q 'INGEST RETRY' "${MAIN}"; then
  echo "FAIL: ingest-and-split stage note must document INGEST RETRY (same spawn_contract goal)" >&2
  exit 1
fi

if [ ! -f "${ROOT}/templates/converge-execute-series-embedded.sh.tftpl" ]; then
  echo "FAIL: missing converge-execute-series-embedded.sh.tftpl" >&2
  exit 1
fi

for stage_tpl in \
  "${ROOT}/templates/iac-pr-execute-series-embedded.sh.tftpl" \
  "${ROOT}/templates/converge-execute-series-embedded.sh.tftpl"; do
  base="$(basename "$stage_tpl")"
  if grep -q 'script_pack_allocate_b64' "$stage_tpl"; then
    echo "FAIL: ${base} must not inline terraform script_pack_*_b64 (runner env sync at tofu apply)" >&2
    exit 1
  fi
  if grep -q "DBSPLIT_.*_EXECUTE" "$stage_tpl"; then
    : # execute_series runs under sh -c; outer /bin/bash heredoc is required for pipefail
  elif ! head -1 "$stage_tpl" | grep -q '/bin/bash'; then
    echo "FAIL: ${base} must invoke /bin/bash (execute_series uses sh -c)" >&2
    exit 1
  fi
  if ! grep -q 'dbsplit_script_pack_env_helpers' "$stage_tpl"; then
    echo "FAIL: ${base} must include dbsplit_script_pack_env_helpers partial" >&2
    exit 1
  fi
done

if ! grep -q 'iac_pr_execute_series_paste_budget' "${MAIN}"; then
  echo "FAIL: main.tf must assert iac-pr execute series paste budget" >&2
  exit 1
fi

if ! grep -q 'converge_execute_series_paste_budget' "${MAIN}"; then
  echo "FAIL: main.tf must assert converge execute series paste budget" >&2
  exit 1
fi

pack_main="$(grep -E 'script_pack_version[[:space:]]*=' "${MAIN}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
pack_runner="$(grep -E '^SCRIPT_PACK_VERSION=' "${ROOT}/scripts/stage-runner.sh" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [ -z "$pack_main" ] || [ -z "$pack_runner" ] || [ "$pack_main" != "$pack_runner" ]; then
  echo "FAIL: script_pack_version mismatch main.tf=${pack_main} stage-runner.sh=${pack_runner}" >&2
  exit 1
fi

if ! grep -q 'shell_tool_prefix' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must reference shell_tool_prefix remote runner tools" >&2
  exit 1
fi

if grep -q 'ubuntu_integration' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not reference ubuntu_integration" >&2
  exit 1
fi

echo "OK: db-state-splitter workflow structure checks passed"
