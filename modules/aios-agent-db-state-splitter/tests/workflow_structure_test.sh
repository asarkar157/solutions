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

if ! grep -q 'blocked:ubuntu_infra_tofu_missing' "${MAIN}"; then
  echo "FAIL: workflow must reference blocked:ubuntu_infra_tofu_missing sentinel" >&2
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

if ! grep -q 'dbsplit_fetch_script_pack' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest embed must git-fetch script pack via GIT_TOKEN" >&2
  exit 1
fi

if ! grep -q "/bin/bash <<'DBSPLIT_INGEST_EXECUTE'" "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest execute series must use /bin/bash heredoc" >&2
  exit 1
fi

if ! grep -q 'dbsplit_resolve_monolith_uri' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest execute series must resolve MONOLITH_URI deterministically" >&2
  exit 1
fi

if ! grep -q 'dbsplit_resolve_work_root' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest execute series must resolve WORK_ROOT without {{workflow_run_id}} placeholder" >&2
  exit 1
fi

if grep -q '{{workflow_run_id}}' "${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"; then
  echo "FAIL: ingest embed must not contain unresolved {{workflow_run_id}} (ONE_LINER is terraform-base64)" >&2
  exit 1
fi

if ! grep -q 'spawn_monolith_uri' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: ingest spawn contract must require spawn_monolith_uri pre-write" >&2
  exit 1
fi

if ! grep -q 'INGEST_EXECUTE_SERIES_B64' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must deliver ingest via INGEST_EXECUTE_SERIES_B64" >&2
  exit 1
fi

if ! grep -q 'INGEST_EXECUTE_SERIES_DECODE_COMMAND' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must deliver ingest decode command" >&2
  exit 1
fi

if ! grep -q 'ingest_execute_series_decode_command' "${MAIN}"; then
  echo "FAIL: main.tf must define ingest_execute_series_decode_command" >&2
  exit 1
fi

if ! grep -q 'create_files' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: ingest spawn_contract must allow create_files for embed b64" >&2
  exit 1
fi

if grep -qF '---BEGIN INGEST_EXECUTE_SERIES---' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must not embed raw INGEST heredoc (use B64 + create_files)" >&2
  exit 1
fi

if ! grep -q 'INGEST_RUNNER_RULE' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must include INGEST_RUNNER_RULE embed guidance" >&2
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

pack_main="$(grep -E 'script_pack_version[[:space:]]*=' "${MAIN}" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
pack_runner="$(grep -E '^SCRIPT_PACK_VERSION=' "${ROOT}/scripts/stage-runner.sh" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
if [ -z "$pack_main" ] || [ -z "$pack_runner" ] || [ "$pack_main" != "$pack_runner" ]; then
  echo "FAIL: script_pack_version mismatch main.tf=${pack_main} stage-runner.sh=${pack_runner}" >&2
  exit 1
fi

echo "OK: db-state-splitter workflow structure checks passed"
