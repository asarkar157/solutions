#!/usr/bin/env bash
# Merge advisory LLM enrichment into catalog/docs without changing dependency graph fields.
set -euo pipefail

cmd_merge() {
  local work_root="${1:?WORK_ROOT}"
  local enrichment="${work_root}/plan-enrichment.yaml"
  local catalog="${work_root}/docs/architecture/service-catalog.yaml"

  if [ ! -f "$enrichment" ]; then
    echo "enrichment_applied=false"
    echo "enrichment_skip_reason=missing_plan_enrichment"
    return 0
  fi

  if jq -e '.depends_on or .modules or .inbound_edges' "$enrichment" >/dev/null 2>&1; then
    echo "enrichment_validation_failed=true"
    echo "enrichment_validation_errors=structural_fields_forbidden"
    exit 1
  fi

  if [ ! -f "$catalog" ]; then
    catalog="${work_root}/service-catalog.yaml"
  fi
  if [ ! -f "$catalog" ]; then
    echo "enrichment_validation_failed=true"
    echo "enrichment_validation_errors=missing_service_catalog"
    exit 1
  fi

  local arch_dir="${work_root}/docs/architecture"
  mkdir -p "$arch_dir"

  for doc in for-developers for-tech-leads for-architects glossary; do
    local src="${work_root}/${doc}.md"
    local dest="${arch_dir}/${doc}.md"
    [ -f "$src" ] && cp "$src" "$dest"
    enrich="$(jq -r --arg d "$doc" '.audience_docs[$d] // empty' "$enrichment" 2>/dev/null || true)"
    if [ -n "$enrich" ] && [ "$enrich" != "null" ] && [ -f "$dest" ]; then
      {
        echo ""
        echo "<!-- LLM enrichment -->"
        printf '%s\n' "$enrich"
      } >>"$dest"
    fi
  done

  local svc_notes
  svc_notes="$(jq -c '.service_notes // {}' "$enrichment" 2>/dev/null || echo '{}')"
  if [ "$svc_notes" != "{}" ] && [ "$svc_notes" != "null" ]; then
    cp "$catalog" "${catalog}.bak"
    while read -r name; do
      [ -n "$name" ] || continue
      sp="$(jq -r --arg n "$name" '.[$n].summary_plain // empty' <<<"$svc_notes")"
      [ -n "$sp" ] || continue
      if grep -q "name:[[:space:]]*${name}" "$catalog"; then
        sed -i.bak "/name:[[:space:]]*${name}/,/^[[:space:]]*- name:/{
          /summary_plain:/c\\
    summary_plain: \"${sp//\"/\\\"}\"
        }" "$catalog" 2>/dev/null || true
      fi
    done < <(jq -r 'keys[]' <<<"$svc_notes")
    rm -f "${catalog}.bak" 2>/dev/null || true
  fi

  echo "enrichment_applied=true"
  echo "enrichment_merge_ok=true"
}

case "${1:-}" in
  merge) shift; cmd_merge "$@" ;;
  *)
    echo "usage: validate-and-merge-enrichment.sh merge WORK_ROOT" >&2
    exit 1
    ;;
esac
