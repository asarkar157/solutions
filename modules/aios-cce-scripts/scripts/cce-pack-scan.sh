#!/usr/bin/env bash
# Parse-once multi-recipe CCE scans (cce plan + cce run -recipes).
# Sourced helpers live in cce-common.sh.
# Usage:
#   cce-pack-scan.sh plan REPO_ROOT [OUTPUT_JSON]
#   cce-pack-scan.sh run-recipes REPO_ROOT RECIPES_CSV OUTPUT_JSON
#   cce-pack-scan.sh summarize REPORT_JSON [TOP_N] [SAMPLE_N]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=cce-common.sh
. "${SCRIPT_DIR}/cce-common.sh"

CCE_USE_REMOTE="${CCE_USE_REMOTE:-1}"

cce_supports_run() {
  cce run -help 2>&1 | grep -q '\-recipes'
}

run_cce_plan() {
  local repo_root="${1:?REPO_ROOT}"
  local output="${2:-}"

  if cce_skip_scan; then
    local skipped
    skipped="$(jq -n '{candidate_files: [], sample_files: [], scan_status: "skipped", reason: "SKIP_CCE"}')"
    if [ -n "$output" ]; then
      mkdir -p "$(dirname "$output")"
      printf '%s' "$skipped" >"$output"
    fi
    printf '%s' "$skipped"
    return 0
  fi

  if ! ensure_cce; then
    local failed
    failed="$(jq -n '{candidate_files: [], sample_files: [], scan_status: "failed", reason: "cce_not_available"}')"
    if [ -n "$output" ]; then
      mkdir -p "$(dirname "$output")"
      printf '%s' "$failed" >"$output"
    fi
    printf '%s' "$failed"
    return 0
  fi

  local tmp_dir plan_raw
  tmp_dir="$(mktemp -d)"
  plan_raw="${tmp_dir}/plan.json"

  if ! cce plan -folder "$repo_root" -language "$(cce_language_flag "${CCE_LANGUAGE:-AUTO}")" \
    >"$plan_raw" 2>"${tmp_dir}/plan.err"; then
    rm -rf "$tmp_dir"
    local failed
    failed="$(jq -n '{candidate_files: [], sample_files: [], scan_status: "failed", reason: "cce_plan_failed"}')"
    if [ -n "$output" ]; then
      mkdir -p "$(dirname "$output")"
      printf '%s' "$failed" >"$output"
    fi
    printf '%s' "$failed"
    return 0
  fi

  local report
  report="$(jq '
    {
      scan_status: "ok",
      candidate_file_count: (.candidate_files | length),
      candidate_files: (.candidate_files // []),
      sample_files: (.sample_files // [])
    }
  ' "$plan_raw")"

  rm -rf "$tmp_dir"
  if [ -n "$output" ]; then
    mkdir -p "$(dirname "$output")"
    printf '%s' "$report" >"$output"
  fi
  printf '%s' "$report"
}

run_cce_recipes_once() {
  local repo_root="${1:?REPO_ROOT}"
  local recipes_csv="${2:?RECIPES}"
  local output="${3:?OUTPUT}"

  if cce_skip_scan; then
    cce_skipped_report "SKIP_CCE" >"$output"
    return 0
  fi

  if ! ensure_cce; then
    cce_failed_report "cce_not_available" >"$output"
    return 0
  fi

  local tmp_dir raw
  tmp_dir="$(mktemp -d)"
  raw="${tmp_dir}/raw.json"

  local -a run_args=(
    run
    -folder "$repo_root"
    -language "$(cce_language_flag "${CCE_LANGUAGE:-AUTO}")"
    -recipes "$recipes_csv"
    -output "$raw"
    -log-level warn
  )
  if [ "$CCE_USE_REMOTE" = "1" ]; then
    run_args+=(-remote)
  fi

  if cce_supports_run && cce "${run_args[@]}" 2>"${tmp_dir}/run.err"; then
    if [ -f "$raw" ]; then
      cp "$raw" "$output"
      rm -rf "$tmp_dir"
      return 0
    fi
  fi

  # Fallback: standalone cloud scan when cce run is unavailable or fails.
  if ! cce \
    -folder "$repo_root" \
    -language "$(cce_language_flag "${CCE_LANGUAGE:-AUTO}")" \
    -filter cloud \
    -format json \
    -output "$raw" \
    -log-level warn 2>"${tmp_dir}/scan.err"; then
    cce_failed_report "cce_run_failed" >"$output"
    rm -rf "$tmp_dir"
    return 0
  fi

  jq -n \
    --slurpfile raw "$raw" \
    --arg recipes "$recipes_csv" \
    '{
      recipes: { "cloud-entitlements": $raw[0] },
      summary: { recipes_run: ($recipes | split(",")), fallback: "standalone_cloud_scan" }
    }' >"$output"
  rm -rf "$tmp_dir"
}

# Build compact report from cce run merged JSON or single recipe entitlement list.
summarize_entitlements() {
  local raw_file="${1:?RAW}"
  local top_n="${2:-10}"
  local sample_n="${3:-15}"

  jq \
    --argjson top_n "$top_n" \
    --argjson sample_n "$sample_n" \
    --arg version "$CCE_VERSION" '
    def ents_from_recipe($r):
      if ($r | type) == "object" and ($r.entitlements | type) == "array" then $r.entitlements
      elif ($r | type) == "array" then $r
      else [] end;

    def all_ents:
      if (.recipes | type) == "object" then
        [.recipes | to_entries[] | ents_from_recipe(.value)] | add // []
      elif (.entitlements | type) == "array" then .entitlements
      else [] end;

    (all_ents) as $all |
    ($all | group_by((.file // "") | split("/")[0]) | map({dir: .[0].file | split("/")[0], count: length}) | sort_by(-.count) | .[0:$top_n]) as $top_dirs |
    {
      scan_status: "ok",
      cce_version: $version,
      entitlements_total: ($all | length),
      summary: {
        total_entitlements: ($all | length),
        by_provider: (
          $all | group_by(.provider // "unknown") | map({key: (.[0].provider // "unknown"), value: length}) | from_entries
        )
      },
      top_directories: $top_dirs,
      sample_entitlements: ($all[0:$sample_n])
    }
  ' "$raw_file"
}

merge_recipe_reports() {
  local pack_file="${1:?PACK_JSON}"
  local recipe_id="${2:?RECIPE_ID}"
  summarize_entitlements <(jq --arg id "$recipe_id" '
    if (.recipes[$id] | type) == "object" then .recipes[$id]
    elif .recipes[$id] != null then { entitlements: .recipes[$id] }
    else { entitlements: [] } end
  ' "$pack_file")
}

case "${1:-}" in
  plan)
    shift
    run_cce_plan "$@"
    ;;
  run-recipes)
    shift
    run_cce_recipes_once "$@"
    ;;
  summarize)
    shift
    summarize_entitlements "$@"
    ;;
  merge-recipe)
    shift
    merge_recipe_reports "$@"
    ;;
  *)
    echo "usage: cce-pack-scan.sh plan|run-recipes|summarize|merge-recipe ..." >&2
    exit 1
    ;;
esac
