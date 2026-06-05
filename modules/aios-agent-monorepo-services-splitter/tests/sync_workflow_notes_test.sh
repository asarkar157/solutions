#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat >"${WORK}/notes.json" <<'EOF'
{
  "deterministic_plan_produced": "true",
  "workflow_notes_snapshot": "{\"service_catalog_yaml\":\"services:\\n- name: analyst-group\\n\",\"llm_patch_applied\":\"true\"}"
}
EOF

bash "${ROOT}/scripts/sync-workflow-notes.sh" sync "$WORK"

if ! jq -e '.service_catalog_yaml' "${WORK}/notes.json" >/dev/null; then
  echo "FAIL: service_catalog_yaml not merged from workflow_notes_snapshot" >&2
  exit 1
fi

cat >"${WORK}/plan-enrichment-snippet.yaml" <<'EOF'
audience_docs:
  for-developers: "Dev guidance"
service_notes: {}
EOF

jq --arg y "$(cat "${WORK}/plan-enrichment-snippet.yaml")" \
  '. + {plan_enrichment_yaml: $y}' "${WORK}/notes.json" >"${WORK}/notes2.json"
mv "${WORK}/notes2.json" "${WORK}/notes.json"

bash "${ROOT}/scripts/materialize-analyst-artifacts.sh" materialize "$WORK"
test -f "${WORK}/plan-enrichment.yaml"
grep -q 'Dev guidance' "${WORK}/plan-enrichment.yaml"

echo "OK: sync workflow notes test passed"
