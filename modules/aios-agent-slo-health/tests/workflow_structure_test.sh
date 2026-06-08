#!/usr/bin/env bash
# Static structure checks for aios-agent-slo-health workflows.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"
WORKFLOWS="${ROOT}/workflows.tf"
RUNBOOKS="${ROOT}/runbooks.tf"
SPAWN="${ROOT}/spawn_contracts.tf"

review_stages=(
  fetch-openslo-specs
  query-slo-metrics
  assess-error-budget
  compose-digest
)

bootstrap_stages=(
  fetch-existing-catalog
  scan-grafana-signals
  propose-slo-candidates
  validate-promql
  no-valid-proposals-gate
  draft-openslo-yaml
  preview-proposals
  confirm-pr-gate
  open-slo-pr
  notify-pr-opened
)

drift_stages=(
  fetch-catalog-and-grafana
  classify-drift-items
  draft-reconcile-yaml
  preview-drift-fixes
  confirm-drift-pr-gate
  open-drift-pr
  notify-drift-pr
)

for stage in "${review_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${WORKFLOWS}"; then
    echo "FAIL: missing review stage ${stage}" >&2
    exit 1
  fi
done

for stage in scan-grafana-config detect-config-drift; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${WORKFLOWS}"; then
    echo "FAIL: missing optional drift-in-review stage ${stage}" >&2
    exit 1
  fi
done

for stage in "${bootstrap_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${WORKFLOWS}"; then
    echo "FAIL: missing bootstrap stage ${stage}" >&2
    exit 1
  fi
done

for stage in "${drift_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${WORKFLOWS}"; then
    echo "FAIL: missing drift reconcile stage ${stage}" >&2
    exit 1
  fi
done

if ! grep -q 'resource "sg_workflow" "slo_health_review"' "${WORKFLOWS}"; then
  echo "FAIL: missing slo_health_review workflow" >&2
  exit 1
fi

if ! grep -q 'resource "sg_workflow" "slo_definition_bootstrap"' "${WORKFLOWS}"; then
  echo "FAIL: missing slo_definition_bootstrap workflow" >&2
  exit 1
fi

if ! grep -q 'resource "sg_workflow" "slo_drift_reconcile"' "${WORKFLOWS}"; then
  echo "FAIL: missing slo_drift_reconcile workflow" >&2
  exit 1
fi

if ! grep -q 'module "weekly_slo_review_schedule"' "${WORKFLOWS}"; then
  echo "FAIL: missing weekly schedule module" >&2
  exit 1
fi

if ! grep -q 'open-slo-pr-runner' "${SPAWN}"; then
  echo "FAIL: missing open-slo-pr-runner spawn contract" >&2
  exit 1
fi

if ! grep -q 'validate-promql-batch-a' "${SPAWN}"; then
  echo "FAIL: missing validate-promql-batch-a spawn contract" >&2
  exit 1
fi

if ! grep -q 'draft-yaml-batch-a' "${SPAWN}"; then
  echo "FAIL: missing draft-yaml-batch-a spawn contract" >&2
  exit 1
fi

if ! grep -q 'write-openslo-drafts' "${ROOT}/scripts/stage-runner.sh"; then
  echo "FAIL: stage-runner must dispatch write-openslo-drafts" >&2
  exit 1
fi

if ! grep -q 'fetch-openslo-specs' "${MAIN}" && ! grep -q 'review_query_depends_on   = \["fetch-openslo-specs"\]' "${MAIN}"; then
  echo "FAIL: review query-slo-metrics must depend on fetch-openslo-specs only (parallel with drift detect)" >&2
  exit 1
fi

if ! grep -q 'flow_type: "parallel"' "${ROOT}/templates/runbook-validate-promql.md"; then
  echo "FAIL: validate-promql runbook must document parallel fan-out" >&2
  exit 1
fi

if ! grep -q 'personas/slo-health-analyst.md' "${MAIN}"; then
  echo "FAIL: missing slo-health-analyst persona" >&2
  exit 1
fi

if ! grep -q 'resource "sg_runbook_sop" "fetch_openslo_specs"' "${RUNBOOKS}"; then
  echo "FAIL: missing fetch_openslo_specs runbook" >&2
  exit 1
fi

if ! test -f "${ROOT}/docs/OPENSLO_REPO_LAYOUT.md"; then
  echo "FAIL: missing docs/OPENSLO_REPO_LAYOUT.md" >&2
  exit 1
fi

if ! test -f "${ROOT}/docs/SLO_CONFIG_DRIFT.md"; then
  echo "FAIL: missing docs/SLO_CONFIG_DRIFT.md" >&2
  exit 1
fi

if ! grep -q 'openslo_authoritative_config_note' "${MAIN}"; then
  echo "FAIL: missing openslo_authoritative_config_note local" >&2
  exit 1
fi

if ! grep -q 'Do NOT call create_agent' "${ROOT}/templates/runbook-fetch-existing-catalog.md.tftpl"; then
  echo "FAIL: fetch-existing-catalog must forbid create_agent" >&2
  exit 1
fi

if ! test -f "${ROOT}/../../openslo/slos/payments-api/availability.yaml"; then
  echo "WARN: openslo/slos samples not at repo root — guild local dev expects solutions/openslo/"
fi

for example in \
  "${ROOT}/templates/openslo-examples/openslo/slos/payments-api/availability.yaml" \
  "${ROOT}/../../openslo/slos/payments-api/availability.yaml" \
  "${ROOT}/templates/openslo-examples/openslo/slos/payments-api/latency-p99.yaml"; do
  if ! command -v python3 >/dev/null 2>&1; then
    break
  fi
  if ! python3 -c "import yaml" 2>/dev/null; then
    echo "WARN: PyYAML not installed — skipping YAML parse of ${example}"
    continue
  fi
  python3 -c "import yaml; yaml.safe_load(open('${example}'))" 2>/dev/null || {
    echo "WARN: invalid YAML in ${example} — skipping parse validation"
  }
done

echo "OK: aios-agent-slo-health workflow structure"
