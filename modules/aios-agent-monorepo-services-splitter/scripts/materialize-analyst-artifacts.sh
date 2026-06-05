#!/usr/bin/env bash
# Copy analyst note blobs (YAML/markdown) into WORK_ROOT files for merge into the guidance PR.
set -euo pipefail

cmd_materialize() {
  local work_root="${1:?WORK_ROOT}"
  local notes="${work_root}/notes.json"
  [ -f "$notes" ] || echo '{}' >"$notes"

  mkdir -p "${work_root}/docs/architecture"
  local wrote=0

  materialize_key() {
    local key="${1:?KEY}"
    local dest="${2:?DEST}"
    local raw
    raw="$(jq -r --arg k "$key" '.[$k] // empty' "$notes" 2>/dev/null || true)"
    if [ -z "$raw" ] || [ "$raw" = "null" ]; then
      return 0
    fi
    printf '%s\n' "$raw" >"$dest"
    echo "materialized_${key}=${dest}"
    wrote=$((wrote + 1))
  }

  materialize_key "service_catalog_yaml" "${work_root}/service-catalog.yaml"
  materialize_key "migration_phases_md" "${work_root}/migration-phases.md"
  materialize_key "migration_phases" "${work_root}/migration-phases.md"
  materialize_key "bounded_context_mermaid" "${work_root}/bounded-context-map.mermaid"
  materialize_key "bounded_context_map_mermaid" "${work_root}/bounded-context-map.mermaid"
  materialize_key "agents_md_analyst_sections" "${work_root}/agents-md-analyst-sections.md"
  materialize_key "plan_enrichment_yaml" "${work_root}/plan-enrichment.yaml"

  if [ "$wrote" -eq 0 ]; then
    echo "analyst_artifacts_materialized=false"
    return 0
  fi

  echo "analyst_artifacts_materialized=true"
  echo "analyst_artifacts_count=${wrote}"
}

case "${1:-}" in
  materialize) shift; cmd_materialize "$@" ;;
  *)
    echo "usage: materialize-analyst-artifacts.sh materialize WORK_ROOT" >&2
    exit 1
    ;;
esac
