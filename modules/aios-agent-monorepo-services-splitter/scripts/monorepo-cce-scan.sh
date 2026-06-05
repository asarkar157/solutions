#!/usr/bin/env bash
# Monorepo CCE critical-path scan — cce plan, scoped cce run -recipes, lens use-case passes.
# Requires CCE_PACK_B64 / CCE_PACK_DIR on the Ubuntu integration environment.
set -euo pipefail

CCE_RECIPES="${CCE_RECIPES:-cloud-entitlements,microservice-decomposition,platform-adoption}"
CCE_LENS_USE_CASES="${CCE_LENS_USE_CASES:-monorepo-intelligence,integration-replatforming}"
CCE_CRITICAL_PATH_MAX_DIRS="${CCE_CRITICAL_PATH_MAX_DIRS:-8}"
CCE_FULL_TREE_MAX_FILES="${CCE_FULL_TREE_MAX_FILES:-800}"
CCE_TOP_DIRS="${CCE_TOP_DIRS:-10}"
CCE_SAMPLE_ENTITLEMENTS="${CCE_SAMPLE_ENTITLEMENTS:-15}"

ensure_cce_pack() {
  local pack_dir="${CCE_PACK_DIR:-/home/integration/.aios-cce/pack}"
  if [ -f "${pack_dir}/cce-pack-scan.sh" ]; then
    export CCE_PACK_DIR="$pack_dir"
    return 0
  fi
  if [ -z "${CCE_PACK_B64:-}" ]; then
    echo "cce_scan_error=missing_cce_pack_b64" >&2
    return 1
  fi
  mkdir -p "$(dirname "$pack_dir")"
  if ! printf '%s' "$CCE_PACK_B64" | tr -d '[:space:]' | base64 -d | tar -xzf - -C "$(dirname "$pack_dir")" 2>/dev/null; then
    echo "cce_scan_error=cce_pack_extract_failed" >&2
    return 1
  fi
  export CCE_PACK_DIR="$pack_dir"
  [ -f "${CCE_PACK_DIR}/cce-pack-scan.sh" ]
}

select_critical_path_dirs() {
  local max_dirs="${1:?MAX}"
  local go_modules="${2:-[]}"
  local js_modules="${3:-[]}"
  local java_modules="${4:-[]}"
  local shared_libs="${5:-[]}"
  local api_surfaces="${6:-[]}"
  local ci_units="${7:-[]}"
  local packages_without_tests="${8:-[]}"

  jq \
    --argjson max "$max_dirs" \
    --argjson go "$go_modules" \
    --argjson js "$js_modules" \
    --argjson java "$java_modules" \
    --argjson shared "$shared_libs" \
    --argjson api "$api_surfaces" \
    --argjson ci "$ci_units" \
    --argjson missing "$packages_without_tests" '
    def top_dir($p):
      if ($p | type) != "string" or $p == "" or $p == "." then empty
      else ($p | split("/")[0]) end;
    def module_dirs($mods):
      [$mods[]? | .path? | top_dir(.)] | map(select(. != null and . != ""));
    def api_dirs:
      [$api[]? | .path? | split("/") | if length > 1 then .[0] else empty end] | map(select(. != null and . != ""));
    def pkg_dirs:
      [$missing[]? | split("/")[0]] | map(select(. != null and . != ""));
    (
      module_dirs($go) + module_dirs($js) + module_dirs($java) +
      [$shared[]? | .path?] +
      api_dirs + [$ci[]? | .path? | split("/") | .[0]] +
      pkg_dirs
    ) | map(select(. != null and . != "" and . != ".")) | unique | .[0:$max]
  '
}

failed_report() {
  jq -n '{scan_status:"failed",summary:{total_entitlements:0,by_provider:{}},top_directories:[],sample_entitlements:[]}'
}

skipped_report() {
  local reason="${1:-skipped}"
  jq -n --arg reason "$reason" \
    '{scan_status:"skipped",reason:$reason,summary:{total_entitlements:0,by_provider:{}},top_directories:[],sample_entitlements:[]}'
}

merge_lens_entitlements() {
  local merged_file="${1:?MERGED}"
  local use_case="${2:?USE_CASE}"
  local part_file="${3:?PART}"
  jq \
    --arg uc "$use_case" \
    --slurpfile part "$part_file" '
    .use_cases[$uc].entitlements = (
      (.use_cases[$uc].entitlements // []) +
      ($part[0].entitlements // [])
    )
  ' "$merged_file"
}

summarize_entitlements_file() {
  local raw_file="${1:?RAW}"
  bash "${CCE_PACK_DIR}/cce-pack-scan.sh" summarize "$raw_file" "$CCE_TOP_DIRS" "$CCE_SAMPLE_ENTITLEMENTS" 2>/dev/null || failed_report
}

run_lens_use_cases_for_scope() {
  local scope_root="${1:?SCOPE_ROOT}"
  local scope_label="${2:?SCOPE_LABEL}"
  local lens_merged="${3:?LENS_MERGED}"
  local use_case scope_out

  while IFS= read -r use_case; do
    [ -n "$use_case" ] || continue
    scope_out="$(dirname "$lens_merged")/lens-${use_case}-${scope_label}.json"
    bash "${CCE_PACK_DIR}/cce-scan.sh" scan-use-case "$scope_root" "$use_case" "$scope_out" 2>/dev/null || continue
    if [ -f "$scope_out" ]; then
      local updated
      updated="$(merge_lens_entitlements "$lens_merged" "$use_case" "$scope_out")"
      printf '%s' "$updated" >"$lens_merged"
    fi
  done < <(printf '%s' "$CCE_LENS_USE_CASES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' || true)
}

run_monorepo_cce_scan() {
  local repo_root="${1:?REPO_ROOT}"
  local work_dir="${2:?WORK_DIR}"
  local go_modules="${3:-[]}"
  local js_modules="${4:-[]}"
  local java_modules="${5:-[]}"
  local shared_libs="${6:-[]}"
  local api_surfaces="${7:-[]}"
  local ci_units="${8:-[]}"
  local packages_without_tests="${9:-[]}"

  mkdir -p "${work_dir}/cce"

  if [ "${MONOREPO_SPLIT_SKIP_CCE:-}" = "1" ] || [ "${SKIP_CCE:-}" = "1" ]; then
    jq -n \
      '{
        scan_status: "skipped",
        reason: "MONOREPO_SPLIT_SKIP_CCE",
        cce_plan: { scan_status: "skipped", candidate_file_count: 0, sample_files: [] },
        critical_path_dirs: [],
        cce_recipes: [],
        cce_lens_use_cases: [],
        cce_reports: {
          cloud_entitlements: { scan_status: "skipped", summary: { total_entitlements: 0, by_provider: {} }, top_directories: [], sample_entitlements: [] },
          outbound_coupling: { scan_status: "skipped", summary: { total_entitlements: 0, by_provider: {} }, top_directories: [], sample_entitlements: [] },
          platform_adoption: { scan_status: "skipped", summary: { total_entitlements: 0, by_provider: {} }, top_directories: [], sample_entitlements: [] },
          monorepo_intelligence: { scan_status: "skipped", summary: { total_entitlements: 0, by_provider: {} }, top_directories: [], sample_entitlements: [] },
          integration_replatforming: { scan_status: "skipped", summary: { total_entitlements: 0, by_provider: {} }, top_directories: [], sample_entitlements: [] }
        },
        cloud_entitlements: { scan_status: "skipped", summary: { total_entitlements: 0, by_provider: {} } }
      }'
    return 0
  fi

  if ! ensure_cce_pack; then
    jq -n \
      '{
        scan_status: "failed",
        reason: "cce_pack_unavailable",
        cce_plan: { scan_status: "failed", candidate_file_count: 0, sample_files: [] },
        critical_path_dirs: [],
        cce_reports: {},
        cloud_entitlements: { scan_status: "failed", summary: { total_entitlements: 0, by_provider: {} } }
      }'
    return 0
  fi

  # shellcheck disable=SC1091
  . "${CCE_PACK_DIR}/cce-common.sh"

  local plan_json critical_dirs candidate_count
  plan_json="$(bash "${CCE_PACK_DIR}/cce-pack-scan.sh" plan "$repo_root" "${work_dir}/cce/plan.json")"
  candidate_count="$(echo "$plan_json" | jq -r '.candidate_file_count // 0')"

  critical_dirs="$(select_critical_path_dirs "$CCE_CRITICAL_PATH_MAX_DIRS" \
    "$go_modules" "$js_modules" "$java_modules" \
    "$shared_libs" "$api_surfaces" "$ci_units" "$packages_without_tests")"

  local scopes='[]'
  if [ "$candidate_count" -le "$CCE_FULL_TREE_MAX_FILES" ]; then
    scopes='["."]'
  elif [ "$(echo "$critical_dirs" | jq 'length')" -gt 0 ]; then
    scopes="$critical_dirs"
  else
    scopes='["."]'
  fi

  local merged="${work_dir}/cce/merged-recipes.json"
  local lens_merged="${work_dir}/cce/merged-lens.json"
  local scope scope_root scope_out scope_label
  echo '{"entitlements":[],"recipes":{}}' >"$merged"
  echo '{"use_cases":{}}' >"$lens_merged"

  while IFS= read -r scope; do
    [ -n "$scope" ] || continue
    if [ "$scope" = "." ]; then
      scope_root="$repo_root"
      scope_label="root"
    else
      scope_root="${repo_root%/}/${scope}"
      scope_label="$(echo "$scope" | tr '/.' '__')"
    fi
    [ -d "$scope_root" ] || continue
    scope_out="${work_dir}/cce/run-${scope_label}.json"
    bash "${CCE_PACK_DIR}/cce-pack-scan.sh" run-recipes "$scope_root" "$CCE_RECIPES" "$scope_out" || true
    if [ -f "$scope_out" ]; then
      merged="$(jq -s '
        .[0] as $acc | .[1] as $part |
        if ($part.recipes | type) == "object" then
          {
            recipes: (
              ($acc.recipes // {}) as $r | ($part.recipes // {}) as $p |
              ($r | keys + ($p | keys) | unique) as $keys |
              reduce $keys[] as $k ({}; . + {
                $k: {
                  entitlements: (($r[$k].entitlements // []) + ($p[$k].entitlements // []))
                }
              })
            )
          }
        elif ($part.entitlements | type) == "array" then
          {
            recipes: {
              "cloud-entitlements": {
                entitlements: (($acc.recipes["cloud-entitlements"].entitlements // []) + $part.entitlements)
              }
            }
          }
        else $acc end
      ' "$merged" "$scope_out")"
      printf '%s' "$merged" >"${work_dir}/cce/merged-recipes.json"
    fi

    if [ -n "${CCE_LENS_USE_CASES// }" ]; then
      run_lens_use_cases_for_scope "$scope_root" "$scope_label" "$lens_merged"
    fi
  done < <(echo "$scopes" | jq -r '.[]')

  local cloud_report outbound_report platform_report mono_report integration_report
  local _failed
  _failed="$(failed_report)"

  if [ -f "$merged" ] && [ "$(jq '.recipes | length' "$merged" 2>/dev/null || echo 0)" -gt 0 ]; then
    cloud_report="$(bash "${CCE_PACK_DIR}/cce-pack-scan.sh" merge-recipe "$merged" cloud-entitlements 2>/dev/null || echo "$_failed")"
    outbound_report="$(bash "${CCE_PACK_DIR}/cce-pack-scan.sh" merge-recipe "$merged" microservice-decomposition 2>/dev/null || echo "$_failed")"
    platform_report="$(bash "${CCE_PACK_DIR}/cce-pack-scan.sh" merge-recipe "$merged" platform-adoption 2>/dev/null || echo "$_failed")"
  else
    cloud_report="$_failed"
    outbound_report="$_failed"
    platform_report="$_failed"
  fi

  if [ -n "${CCE_LENS_USE_CASES// }" ] && [ -f "$lens_merged" ]; then
    local mono_raw integration_raw
    mono_raw="${work_dir}/cce/lens-raw-monorepo-intelligence.json"
    integration_raw="${work_dir}/cce/lens-raw-integration-replatforming.json"
    jq --arg uc "monorepo-intelligence" \
      'if (.use_cases[$uc].entitlements | type) == "array" then {entitlements: .use_cases[$uc].entitlements} else {entitlements: []} end' \
      "$lens_merged" >"$mono_raw"
    jq --arg uc "integration-replatforming" \
      'if (.use_cases[$uc].entitlements | type) == "array" then {entitlements: .use_cases[$uc].entitlements} else {entitlements: []} end' \
      "$lens_merged" >"$integration_raw"
    mono_report="$(summarize_entitlements_file "$mono_raw")"
    integration_report="$(summarize_entitlements_file "$integration_raw")"
  else
    mono_report="$(skipped_report "lens_use_cases_disabled")"
    integration_report="$(skipped_report "lens_use_cases_disabled")"
  fi

  local lens_cases_json recipes_json
  lens_cases_json="$(printf '%s' "$CCE_LENS_USE_CASES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | jq -R . | jq -s . || echo '[]')"
  recipes_json="$(printf '%s' "$CCE_RECIPES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | jq -R . | jq -s .)"

  jq -n \
    --argjson plan "$plan_json" \
    --argjson critical "$critical_dirs" \
    --argjson scopes "$scopes" \
    --argjson cloud "$cloud_report" \
    --argjson outbound "$outbound_report" \
    --argjson platform "$platform_report" \
    --argjson mono "$mono_report" \
    --argjson integration "$integration_report" \
    --argjson recipes "$recipes_json" \
    --argjson lens_cases "$lens_cases_json" \
    '{
      scan_status: "ok",
      cce_recipes: $recipes,
      cce_lens_use_cases: $lens_cases,
      cce_plan: $plan,
      critical_path_dirs: $critical,
      scan_scopes: $scopes,
      cce_reports: {
        cloud_entitlements: $cloud,
        outbound_coupling: $outbound,
        platform_adoption: $platform,
        monorepo_intelligence: $mono,
        integration_replatforming: $integration
      },
      cloud_entitlements: $cloud
    }'
}

build_cce_summary() {
  local cce_blob="${1:?CCE_JSON}"
  jq '
    {
      scan_status: (.scan_status // "unknown"),
      cce_candidate_files: (.cce_plan.candidate_file_count // 0),
      critical_path_dirs: (.critical_path_dirs // []),
      cloud_by_provider: (.cce_reports.cloud_entitlements.summary.by_provider // {}),
      outbound_by_provider: (.cce_reports.outbound_coupling.summary.by_provider // {}),
      platform_by_provider: (.cce_reports.platform_adoption.summary.by_provider // {}),
      monorepo_by_provider: (.cce_reports.monorepo_intelligence.summary.by_provider // {}),
      integration_by_provider: (.cce_reports.integration_replatforming.summary.by_provider // {}),
      top_directories: (
        (.cce_reports.cloud_entitlements.top_directories // []) +
        (.cce_reports.outbound_coupling.top_directories // []) +
        (.cce_reports.platform_adoption.top_directories // []) +
        (.cce_reports.monorepo_intelligence.top_directories // []) +
        (.cce_reports.integration_replatforming.top_directories // [])
        | group_by(.dir) | map({dir: .[0].dir, count: (map(.count) | add)}) | sort_by(-.count) | .[0:10]
      ),
      outbound_coupling_dirs: (.cce_reports.outbound_coupling.top_directories // []),
      cloud_entitlements_total: (.cce_reports.cloud_entitlements.summary.total_entitlements // 0),
      entitlements_sample_count: (
        (.cce_reports.cloud_entitlements.sample_entitlements // []) | length
      )
    }
  ' <<<"$cce_blob"
}

run_targeted_cce_scan() {
  local repo_root="${1:?REPO_ROOT}"
  local work_root="${2:?WORK_ROOT}"
  local spec_json="${3:?SPEC_JSON}"

  mkdir -p "${work_root}/.work/cce"

  if ! ensure_cce_pack; then
    echo "targeted_cce_error=cce_pack_unavailable" >&2
    return 1
  fi

  local recipes mapper_url use_case custom_lens scopes
  recipes="$(echo "$spec_json" | jq -r '(.recipes // ["microservice-decomposition"]) | join(",")')"
  mapper_url="$(echo "$spec_json" | jq -r '.mapper_url // empty')"
  use_case="$(echo "$spec_json" | jq -r '.use_case // empty')"
  scopes="$(echo "$spec_json" | jq -c '.folder_scopes // ["."]')"

  if [ -n "${CCE_CUSTOM_LENS_YAML:-}" ]; then
    custom_lens="${work_root}/.work/cce/custom-lens.yaml"
    printf '%s' "$CCE_CUSTOM_LENS_YAML" >"$custom_lens"
    export CCE_MAPPER_FILE="$custom_lens"
    export CCE_FILTER="${CCE_FILTER:-all}"
    unset CCE_USE_CASE
  elif [ -n "$mapper_url" ]; then
    export CCE_MAPPER_FILE="$mapper_url"
    export CCE_FILTER="${CCE_FILTER:-all}"
    unset CCE_USE_CASE
  elif [ -n "$use_case" ]; then
    unset CCE_MAPPER_FILE
    export CCE_USE_CASE="$use_case"
    export CCE_FILTER="${CCE_FILTER:-all}"
  fi

  local merged="${work_root}/.work/cce/targeted-merged.json"
  echo '{"recipes":{}}' >"$merged"

  local scope scope_root scope_out
  while IFS= read -r scope; do
    [ -n "$scope" ] || continue
    if [ "$scope" = "." ]; then
      scope_root="$repo_root"
    else
      scope_root="${repo_root%/}/${scope}"
    fi
    [ -d "$scope_root" ] || continue
    scope_out="${work_root}/.work/cce/targeted-$(echo "$scope" | tr '/.' '__').json"
    if [ -n "${CCE_MAPPER_FILE:-}" ]; then
      bash "${CCE_PACK_DIR}/cce-scan.sh" scan "$scope_root" "$scope_out" || true
    elif [ -n "${CCE_USE_CASE:-}" ]; then
      bash "${CCE_PACK_DIR}/cce-scan.sh" scan-use-case "$scope_root" "$CCE_USE_CASE" "$scope_out" || true
    else
      bash "${CCE_PACK_DIR}/cce-pack-scan.sh" run-recipes "$scope_root" "$recipes" "$scope_out" || true
    fi
    if [ -f "$scope_out" ]; then
      merged="$(jq -s '
        .[0] as $acc | .[1] as $part |
        if ($part.recipes | type) == "object" then
          { recipes: ( ($acc.recipes // {}) + ($part.recipes // {}) | to_entries | map(.value.entitlements = ((.value.entitlements // []) + ($part.recipes[.key].entitlements // []))) | from_entries ) }
        elif ($part.entitlements | type) == "array" then
          { recipes: { targeted: { entitlements: (($acc.recipes.targeted.entitlements // []) + $part.entitlements) } } }
        else $acc end
      ' "$merged" "$scope_out" 2>/dev/null || echo "$merged")"
      printf '%s' "$merged" >"${work_root}/.work/cce/targeted-merged.json"
    fi
  done < <(echo "$scopes" | jq -r '.[]')

  local targeted_report
  if [ -f "$merged" ]; then
    targeted_report="$(bash "${CCE_PACK_DIR}/cce-pack-scan.sh" summarize "$merged" "$CCE_TOP_DIRS" "$CCE_SAMPLE_ENTITLEMENTS" 2>/dev/null || jq -n '{scan_status:"failed"}')"
  else
    targeted_report="$(jq -n '{scan_status:"failed",reason:"no_targeted_output"}')"
  fi

  printf '%s' "$targeted_report" >"${work_root}/.work/cce/targeted-summary.json"
  jq -n \
    --argjson targeted "$targeted_report" \
    --argjson spec "$spec_json" \
    '{ scan_status: "ok", targeted_cce: $targeted, spec: $spec }'
}

case "${1:-}" in
  scan)
    shift
    run_monorepo_cce_scan "$@"
    ;;
  summary)
    shift
    build_cce_summary "$@"
    ;;
  targeted)
    shift
    run_targeted_cce_scan "$@"
    ;;
  *)
    echo "usage: monorepo-cce-scan.sh scan|summary|targeted ..." >&2
    exit 1
    ;;
esac
