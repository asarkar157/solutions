#!/usr/bin/env bash
# Static checks for cross-platform-alert-triage workflow in main.tf.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN="${ROOT}/main.tf"
SPAWN="${ROOT}/spawn_contracts.tf"

required_stages=(
  grafana-ingest-filter
  normalize-alert
  search-prior-incidents
  classify-symptom-cause
  collect-grafana-signals
  probe-grafana-queries
  enrich-k8s-context
  cross-signal-investigate
  synthesize-rca
  persist-incident-memory
  cloud-triage
  notify-slack
)

for stage in "${required_stages[@]}"; do
  if ! grep -q "stage_id[[:space:]]*=[[:space:]]*\"${stage}\"" "${MAIN}"; then
    echo "FAIL: missing stage_id ${stage} in main.tf" >&2
    exit 1
  fi
done

for agent in grafana-alert-ingest rca-investigator alert-triage-coordinator; do
  if ! grep -q "personas/${agent}.md" "${MAIN}"; then
    echo "FAIL: main.tf must reference personas/${agent}.md" >&2
    exit 1
  fi
done

if [[ ! -f "${ROOT}/_persona_guard.tf" ]]; then
  echo "FAIL: missing _persona_guard.tf" >&2
  exit 1
fi

if ! grep -q 'spawn_contracts_hypothesis_tree' "${MAIN}"; then
  echo "FAIL: cross-signal-investigate must set spawn_contracts" >&2
  exit 1
fi

for hypo in hypothesis-deploy-regression hypothesis-capacity hypothesis-config-drift hypothesis-dependency hypothesis-network-topology; do
  if ! grep -q "${hypo}" "${SPAWN}"; then
    echo "FAIL: spawn_contracts must register ${hypo}" >&2
    exit 1
  fi
done

if ! grep -q 'memory_enabled' "${MAIN}"; then
  echo "FAIL: agents must enable knowledge.memory_enabled" >&2
  exit 1
fi

if ! grep -q 'alert-ingest-filter.rego.tftpl' "${MAIN}"; then
  echo "FAIL: main.tf must template alert-ingest-filter.rego.tftpl" >&2
  exit 1
fi

echo "OK: alert-triage workflow structure checks passed"
