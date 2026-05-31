#!/usr/bin/env bash
# Static checks for db-monorepo-state-split-convergence workflow in main.tf.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"

required_stages=(
  ingest-and-split
  split-input-gate
  split-ingest-blocked-gate
  split-loop-gate
  registry-and-import-codegen
  hcl-hydrate-per-group
  materialize-stackgen-appstacks
  orphans-secondary-pipeline
  multi-shard-plan-convergence
  multi-shard-plan-infra-gate
  multi-shard-plan-loop-gate
  final-gate-and-memory
)

for stage in "${required_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing stage_id ${stage} in main.tf" >&2
    exit 1
  fi
done

# Legacy split stages must not return (4 architect turns removed).
for legacy in discover-db-anchors allocate-related-resources count-reconcile-loop count-reconcile-loop-gate ingest-monolith; do
  if grep -q "stage_id[[:space:]]*=[[:space:]]*\"${legacy}\"" "${MAIN}"; then
    echo "FAIL: legacy stage ${legacy} still present — use ingest-and-split" >&2
    exit 1
  fi
done

if ! grep -q 'action_type[[:space:]]*=[[:space:]]*"loop_stage"' "${MAIN}"; then
  echo "FAIL: workflow must define loop_stage gates" >&2
  exit 1
fi

if ! grep -q 'action_type[[:space:]]*=[[:space:]]*"conditional_skip"' "${MAIN}"; then
  echo "FAIL: workflow must define conditional_skip for missing monolith URI" >&2
  exit 1
fi

if ! grep -q 'blocked:missing_monolith_state_uri' "${MAIN}"; then
  echo "FAIL: ingest must emit blocked:missing_monolith_state_uri sentinel" >&2
  exit 1
fi

if ! grep -q 'blocked:ubuntu_infra_tofu_missing' "${MAIN}"; then
  echo "FAIL: workflow must define blocked:ubuntu_infra_tofu_missing infra sentinel" >&2
  exit 1
fi

if ! grep -q 'blocked:three_runner_attempts_failed' "${MAIN}"; then
  echo "FAIL: ingest must emit blocked:three_runner_attempts_failed sentinel" >&2
  exit 1
fi

if ! grep -q 'multi-shard-plan-infra-gate' "${MAIN}"; then
  echo "FAIL: missing multi-shard-plan-infra-gate conditional_skip" >&2
  exit 1
fi

if ! grep -q 'split-ingest-blocked-gate' "${MAIN}"; then
  echo "FAIL: missing split-ingest-blocked-gate conditional_skip" >&2
  exit 1
fi

if ! grep -q 'output_matches_regex' "${MAIN}"; then
  echo "FAIL: conditional_skip gates must use output_matches_regex for ingest/infra blockers" >&2
  exit 1
fi

if ! grep -q 'split-loop-gate' "${MAIN}"; then
  echo "FAIL: missing split-loop-gate" >&2
  exit 1
fi

if ! grep -q 'multi-shard-plan-loop-gate' "${MAIN}"; then
  echo "FAIL: missing multi-shard-plan-loop-gate" >&2
  exit 1
fi

if ! grep -q '"action":"GO_BACK"' "${MAIN}"; then
  echo "FAIL: downstream stages must block when predecessor emits GO_BACK JSON" >&2
  exit 1
fi

if ! grep -q 'mock_provider' "${MAIN}"; then
  echo "FAIL: registry scaffold must require mock_provider in optional tftest files" >&2
  exit 1
fi

if ! grep -q '$HOME/.<workflow_run_id>/' "${MAIN}"; then
  echo "FAIL: scratch paths must use stagerunner workflow_run_id" >&2
  exit 1
fi

if ! grep -q 'appstack-materialize-runner-batch' "${MAIN}"; then
  echo "FAIL: materialize must mandate parallel appstack batch fan-out" >&2
  exit 1
fi

if ! grep -q 'flow_type:"parallel"' "${MAIN}"; then
  echo "FAIL: parallel batch fan-out must use flow_type parallel" >&2
  exit 1
fi

if ! grep -q 'ingest-and-split' "${MAIN}"; then
  echo "FAIL: workflow must use consolidated ingest-and-split stage" >&2
  exit 1
fi

if ! grep -q 'ingest-and-split' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must support ingest-and-split command" >&2
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

if ! grep -q 'verify-script-pack' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must support verify-script-pack" >&2
  exit 1
fi

if ! grep -q 'emit_script_pack_verify' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must emit script_pack_verify_ok after split" >&2
  exit 1
fi

if ! grep -q 'stage_depends_on = \["split-loop-gate", "ingest-and-split"\]' "${MAIN}"; then
  echo "FAIL: split-ingest-blocked-gate must fan-in ingest-and-split for gate regex matching" >&2
  exit 1
fi

if ! grep -q 'stage_depends_on = \["split-input-gate", "ingest-and-split"\]' "${MAIN}"; then
  echo "FAIL: split-loop-gate must fan-in ingest-and-split for count_reconciliation_ok matching" >&2
  exit 1
fi

if ! grep -q 'stage_depends_on = \["multi-shard-plan-infra-gate", "multi-shard-plan-convergence"\]' "${MAIN}"; then
  echo "FAIL: multi-shard-plan-loop-gate must fan-in multi-shard-plan-convergence for plan sentinel matching" >&2
  exit 1
fi

if ! grep -q 'count_reconciliation_ok: \\\"false\\\"' "${MAIN}"; then
  echo "FAIL: split-ingest-blocked-gate must match count_reconciliation_ok false" >&2
  exit 1
fi

if ! grep -q 'INGEST STOP RULE' "${MAIN}"; then
  echo "FAIL: ingest stage must define INGEST STOP RULE to prevent post-success thrash" >&2
  exit 1
fi

if ! grep -q 'ingest-and-split-runner' "${ROOT}/spawn_contracts.tf"; then
  echo "FAIL: spawn_contracts must register ingest-and-split-runner" >&2
  exit 1
fi

echo "OK: db-state-splitter workflow structure checks passed"
