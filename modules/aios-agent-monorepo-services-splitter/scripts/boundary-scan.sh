#!/usr/bin/env bash
# Monorepo boundary scan — language detection, dependency coupling, and test inventory.
# Writes $WORK_ROOT/boundary_scan.json and mirrors key paths to notes.json.
set -euo pipefail

SCRIPT_PACK_VERSION="${SCRIPT_PACK_VERSION:-20260602.14}"

mirror_note() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  local value="${3:?VALUE}"
  local notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"
  jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$notes" >"${notes}.tmp" \
    && mv "${notes}.tmp" "$notes"
}

repo_has_java_build() {
  local root="${1:?REPO_ROOT}"
  [ -f "$root/pom.xml" ] \
    || [ -f "$root/build.gradle" ] \
    || [ -f "$root/build.gradle.kts" ] \
    || [ -f "$root/settings.gradle" ] \
    || [ -f "$root/settings.gradle.kts" ] \
    || [ -f "$root/gradlew" ]
}

detect_languages() {
  local root="${1:?REPO_ROOT}"
  local langs=()

  if [ -f "$root/go.mod" ]; then
    langs+=("go")
  fi
  if [ -f "$root/package.json" ] || [ -f "$root/pnpm-workspace.yaml" ] || [ -f "$root/yarn.lock" ]; then
    langs+=("typescript")
  fi
  if repo_has_java_build "$root"; then
    langs+=("java")
  fi

  if [ "${#langs[@]}" -eq 0 ]; then
    langs+=("unknown")
  fi

  printf '%s\n' "${langs[@]}" | jq -R . | jq -s .
}

detect_junit_in_gradle_tree() {
  local root="${1:?REPO_ROOT}"
  local libs_toml="$root/gradle/libs.versions.toml"
  if [ -f "$libs_toml" ] && grep -qE 'junit|jupiter' "$libs_toml" 2>/dev/null; then
    return 0
  fi
  if find "$root" -maxdepth 4 -type f \( -name 'build.gradle' -o -name 'build.gradle.kts' \) 2>/dev/null \
    | grep -vE '/(build|target|\.gradle)/' \
    | head -40 \
    | xargs grep -lE 'junit-jupiter|junit:junit|org\.junit|useJUnitPlatform' 2>/dev/null \
    | head -1 | grep -q .; then
    return 0
  fi
  return 1
}

scan_go_modules() {
  local root="${1:?REPO_ROOT}"
  if [ ! -f "$root/go.mod" ]; then
    echo '[]'
    return 0
  fi
  (
    cd "$root"
    if ! command -v go >/dev/null 2>&1; then
      echo '[]'
      return 0
    fi
    go list -json ./... 2>/dev/null | jq -s '
      map(select(.ImportPath != null)) |
      map({
        path: .ImportPath,
        language: "go",
        dir: (.Dir // ""),
        inbound_edges: 0,
        outbound_edges: ((.Imports // []) | length)
      })
    ' 2>/dev/null || echo '[]'
  )
}

scan_js_modules() {
  local root="${1:?REPO_ROOT}"
  if [ ! -f "$root/package.json" ] && [ ! -f "$root/pnpm-workspace.yaml" ]; then
    echo '[]'
    return 0
  fi

  local modules='[]'
  if [ -f "$root/pnpm-workspace.yaml" ]; then
    modules="$(grep -E '^\s*-\s+' "$root/pnpm-workspace.yaml" 2>/dev/null | sed 's/^\s*-\s*//' | while read -r pkg; do
      [ -d "$root/$pkg" ] && printf '%s\n' "$pkg"
    done | jq -R . | jq -s 'map({path: ., language: "typescript", inbound_edges: 0, outbound_edges: 0})' || echo '[]')"
  elif [ -f "$root/package.json" ]; then
    modules='[{"path": ".", "language": "typescript", "inbound_edges": 0, "outbound_edges": 0}]'
  fi
  printf '%s' "$modules"
}

scan_java_modules() {
  local root="${1:?REPO_ROOT}"
  if ! repo_has_java_build "$root"; then
    echo '[]'
    return 0
  fi

  if [ -f "$root/settings.gradle" ] || [ -f "$root/settings.gradle.kts" ]; then
    local settings="$root/settings.gradle"
    [ -f "$root/settings.gradle.kts" ] && settings="$root/settings.gradle.kts"
    local subs
    subs="$(grep -E 'include\s*\(' "$settings" 2>/dev/null \
      | sed -E 's/.*include\s*\(\s*"([^"]+)".*/\1/; s/.*include\s*\(\s*'\''([^'\'']+)'\''.*/\1/' \
      | grep -vE '^include' \
      | head -60 || true)"
    if [ -n "$subs" ]; then
      printf '%s\n' "$subs" | jq -R . | jq -s 'map({path: ., language: "java", inbound_edges: 0, outbound_edges: 0})'
      return 0
    fi
  fi

  echo '[{"path": ".", "language": "java", "inbound_edges": 0, "outbound_edges": 0}]'
}

find_api_surfaces() {
  local root="${1:?REPO_ROOT}"
  local paths
  paths="$(find "$root" -type f \( -name 'openapi.yml' -o -name 'openapi.yaml' -o -name '*.proto' \) 2>/dev/null | head -50 || true)"
  if [ -z "$paths" ]; then
    echo '[]'
    return 0
  fi
  printf '%s\n' "$paths" | jq -R . | jq -s 'map({path: ., kind: (if endswith(".proto") then "proto" else "openapi" end)})'
}

find_ci_deploy_units() {
  local root="${1:?REPO_ROOT}"
  if [ ! -d "$root/.github/workflows" ]; then
    echo '[]'
    return 0
  fi
  local paths
  paths="$(find "$root/.github/workflows" -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | head -30 || true)"
  if [ -z "$paths" ]; then
    echo '[]'
    return 0
  fi
  printf '%s\n' "$paths" | jq -R . | jq -s 'map({path: ., kind: "github_workflow"})'
}

find_shared_libraries() {
  local root="${1:?REPO_ROOT}"
  local libs=()
  for candidate in pkg lib libs common shared internal/core; do
    if [ -d "$root/$candidate" ]; then
      libs+=("$candidate")
    fi
  done
  if [ "${#libs[@]}" -eq 0 ]; then
    echo '[]'
    return 0
  fi
  printf '%s\n' "${libs[@]}" | jq -R . | jq -s 'map({path: ., rationale: "conventional shared directory name"})'
}

# --- Test inventory (language-specific unit-test signals) ---

count_files_under() {
  local root="${1:?}"
  local pattern="${2:?}"
  find "$root" -type f -name "$pattern" 2>/dev/null \
    | grep -vE '/(vendor|node_modules|\.git|dist|build|target)/' \
    | wc -l | tr -d ' '
}

scan_go_test_inventory() {
  local root="${1:?REPO_ROOT}"
  if [ ! -f "$root/go.mod" ]; then
    echo 'null'
    return 0
  fi

  local test_files_count
  test_files_count="$(count_files_under "$root" '*_test.go')"

  local packages_total=0 packages_with_tests=0 packages_without_tests='[]' runnable_modules='[]'
  if command -v go >/dev/null 2>&1; then
    local all_pkgs tested_pkgs
    all_pkgs="$(cd "$root" && go list ./... 2>/dev/null | grep -v '/vendor/' || true)"
    tested_pkgs="$(cd "$root" && go list -f '{{if len .TestGoFiles}}{{.ImportPath}}{{end}}' ./... 2>/dev/null | grep -v '^$' || true)"
    if [ -n "$all_pkgs" ]; then
      packages_total="$(printf '%s\n' "$all_pkgs" | grep -c . || echo 0)"
    fi
    if [ -n "$tested_pkgs" ]; then
      packages_with_tests="$(printf '%s\n' "$tested_pkgs" | grep -c . || echo 0)"
    fi
    if [ -n "$all_pkgs" ] && [ -n "$tested_pkgs" ]; then
      packages_without_tests="$(comm -23 <(printf '%s\n' "$all_pkgs" | sort) <(printf '%s\n' "$tested_pkgs" | sort) | jq -R . | jq -s .)"
    elif [ -n "$all_pkgs" ]; then
      packages_without_tests="$(printf '%s\n' "$all_pkgs" | jq -R . | jq -s .)"
    fi
    if cd "$root" && go test -list=. ./... >/dev/null 2>&1; then
      runnable_modules='["./..."]'
    fi
  fi

  jq -n \
    --argjson test_files_count "$test_files_count" \
    --argjson packages_total "$packages_total" \
    --argjson packages_with_tests "$packages_with_tests" \
    --argjson packages_without_tests "$packages_without_tests" \
    --argjson runnable_modules "$runnable_modules" \
    '{
      test_files_count: $test_files_count,
      packages_total: $packages_total,
      packages_with_tests: $packages_with_tests,
      packages_without_tests: $packages_without_tests,
      runnable_modules: $runnable_modules,
      recommended_command: "go test ./... -race -count=1",
      coverage_command: "go test ./... -coverprofile=coverage.out",
      patterns: ["*_test.go co-located with source", "table-driven tests with t.Run"]
    }'
}

scan_java_test_inventory() {
  local root="${1:?REPO_ROOT}"
  if ! repo_has_java_build "$root"; then
    echo 'null'
    return 0
  fi

  local build_tool="unknown" junit_detected=false surefire_configured=false
  local test_src_dirs='[]' test_java_count=0

  if [ -f "$root/pom.xml" ]; then
    build_tool="maven"
    if grep -qE 'junit-jupiter|junit-jupiter-api|junit:junit' "$root/pom.xml" 2>/dev/null; then
      junit_detected=true
    fi
    if grep -qE 'maven-surefire-plugin|surefire' "$root/pom.xml" 2>/dev/null; then
      surefire_configured=true
    fi
  fi
  if [ -f "$root/build.gradle" ] || [ -f "$root/build.gradle.kts" ] || [ -f "$root/settings.gradle" ] || [ -f "$root/settings.gradle.kts" ] || [ -f "$root/gradlew" ]; then
    build_tool="gradle"
    local gradle_file="$root/build.gradle"
    [ -f "$root/build.gradle.kts" ] && gradle_file="$root/build.gradle.kts"
    if [ -f "$gradle_file" ]; then
      if grep -qE 'junit-jupiter|junit:junit|org\.junit' "$gradle_file" 2>/dev/null; then
        junit_detected=true
      fi
      if grep -qE 'useJUnitPlatform|test\s*\{' "$gradle_file" 2>/dev/null; then
        surefire_configured=true
      fi
    fi
    if [ "$junit_detected" = false ] && detect_junit_in_gradle_tree "$root"; then
      junit_detected=true
      surefire_configured=true
    fi
    if [ "$surefire_configured" = false ] && [ -f "$root/gradlew" ]; then
      surefire_configured=true
    fi
  fi

  local test_dirs
  test_dirs="$(find "$root" -type d \( -path '*/src/test/java' -o -path '*/src/test/kotlin' \) 2>/dev/null \
    | grep -vE '/(target|build|\.gradle)/' | head -30 || true)"
  if [ -n "$test_dirs" ]; then
    test_src_dirs="$(printf '%s\n' "$test_dirs" | sed "s|^${root}/||" | jq -R . | jq -s .)"
    test_java_count="$(find "$root" -type f \( -path '*/src/test/java/*Test.java' -o -path '*/src/test/java/*Tests.java' -o -path '*/src/test/kotlin/*Test.kt' \) 2>/dev/null \
      | grep -vE '/(target|build)/' | wc -l | tr -d ' ')"
  fi

  local recommended_command="mvn test"
  local java_version_required="17"
  if [ -f "$root/.java-version" ]; then
    java_version_required="$(tr -d 'v' <"$root/.java-version" | head -1 | cut -d. -f1)"
  fi
  if [ -f "$root/pom.xml" ]; then
    local pom_java
    pom_java="$(grep -E 'maven\.compiler\.(source|release)|java\.version' "$root/pom.xml" 2>/dev/null | grep -Eo '[0-9]+' | head -1 || true)"
    [ -n "$pom_java" ] && java_version_required="$pom_java"
  fi
  if [ "$build_tool" = "gradle" ]; then
    recommended_command="./gradlew test"
    local gradle_file="$root/build.gradle"
    [ -f "$root/build.gradle.kts" ] && gradle_file="$root/build.gradle.kts"
    if [ -f "$gradle_file" ]; then
      local gradle_java
      gradle_java="$(grep -Eo 'JavaLanguageVersion\.of\([0-9]+\)|VERSION_[0-9_]+' "$gradle_file" 2>/dev/null | grep -Eo '[0-9]+' | head -1 || true)"
      [ -n "$gradle_java" ] && java_version_required="$gradle_java"
    fi
  fi

  jq -n \
    --arg build_tool "$build_tool" \
    --arg java_version_required "$java_version_required" \
    --argjson junit_detected "$junit_detected" \
    --argjson surefire_configured "$surefire_configured" \
    --argjson test_src_dirs "$test_src_dirs" \
    --argjson test_java_count "$test_java_count" \
    --arg recommended_command "$recommended_command" \
    '{
      build_tool: $build_tool,
      java_version_required: $java_version_required,
      junit_detected: $junit_detected,
      surefire_configured: $surefire_configured,
      test_src_dirs: $test_src_dirs,
      test_java_count: $test_java_count,
      recommended_command: $recommended_command,
      unit_vs_integration: "prefer JUnit 5 unit tests in src/test; use Testcontainers only at module boundaries"
    }'
}

scan_js_test_inventory() {
  local root="${1:?REPO_ROOT}"
  if [ ! -f "$root/package.json" ] && [ ! -f "$root/pnpm-workspace.yaml" ]; then
    echo 'null'
    return 0
  fi

  local test_ts_count test_spec_js_count test_spec_ts_count
  test_ts_count="$(count_files_under "$root" '*.test.ts')"
  test_spec_ts_count="$(count_files_under "$root" '*.spec.ts')"
  test_spec_js_count="$(count_files_under "$root" '*.spec.js')"

  local config_files='[]'
  config_files="$(find "$root" -maxdepth 4 -type f \( \
    -name 'vitest.config.ts' -o -name 'vitest.config.js' -o -name 'vitest.config.mts' \
    -o -name 'jest.config.js' -o -name 'jest.config.ts' -o -name 'jest.config.cjs' \
    \) 2>/dev/null | grep -v node_modules | sed "s|^${root}/||" | jq -R . | jq -s . || echo '[]')"

  local frameworks='[]'
  if echo "$config_files" | jq -e 'map(select(test("vitest"))) | length > 0' >/dev/null 2>&1; then
    frameworks='["vitest"]'
  fi
  if echo "$config_files" | jq -e 'map(select(test("jest"))) | length > 0' >/dev/null 2>&1; then
    frameworks="$(echo "$frameworks" | jq '. + ["jest"]')"
  fi
  if [ -f "$root/package.json" ] && grep -qE '"mocha"' "$root/package.json" 2>/dev/null; then
    frameworks="$(echo "$frameworks" | jq '. + ["mocha"]')"
  fi

  local pkg_paths='["."]'
  if [ -f "$root/pnpm-workspace.yaml" ]; then
    pkg_paths="$(grep -E '^\s*-\s+' "$root/pnpm-workspace.yaml" 2>/dev/null | sed 's/^\s*-\s*//' | while read -r pkg; do
      [ -d "$root/$pkg" ] && printf '%s\n' "$pkg"
    done | jq -R . | jq -s .)"
  fi

  local packages_with_test_script='[]' packages_without_tests='[]'
  while IFS= read -r pkg; do
    local pkg_json="$root/$pkg/package.json"
    [ "$pkg" = "." ] && pkg_json="$root/package.json"
    [ -f "$pkg_json" ] || continue
    if jq -e '.scripts.test // .scripts["test:unit"]' "$pkg_json" >/dev/null 2>&1; then
      packages_with_test_script="$(echo "$packages_with_test_script" | jq --arg p "$pkg" '. + [$p]')"
      continue
    fi
    local search_dir="$root/$pkg"
    [ "$pkg" = "." ] && search_dir="$root"
    if ! find "$search_dir" -maxdepth 5 -type f \( -name '*.test.ts' -o -name '*.spec.ts' -o -name '*.test.js' -o -name '*.spec.js' \) 2>/dev/null | grep -q .; then
      packages_without_tests="$(echo "$packages_without_tests" | jq --arg p "$pkg" '. + [$p]')"
    fi
  done < <(echo "$pkg_paths" | jq -r '.[]')

  jq -n \
    --argjson test_files_count "$((test_ts_count + test_spec_ts_count + test_spec_js_count))" \
    --argjson test_ts_count "$test_ts_count" \
    --argjson test_spec_ts_count "$test_spec_ts_count" \
    --argjson test_spec_js_count "$test_spec_js_count" \
    --argjson config_files "$config_files" \
    --argjson packages_with_test_script "$packages_with_test_script" \
    --argjson packages_without_tests "$packages_without_tests" \
    '{
      test_files_count: $test_files_count,
      test_ts_count: $test_ts_count,
      test_spec_ts_count: $test_spec_ts_count,
      test_spec_js_count: $test_spec_js_count,
      config_files: $config_files,
      packages_with_test_script: $packages_with_test_script,
      packages_without_tests: $packages_without_tests,
      recommended_command: "pnpm test --filter <package> or npm test -w <package>",
      coverage_command: "vitest run --coverage or jest --coverage"
    }'
}

scan_test_inventory() {
  local root="${1:?REPO_ROOT}"
  local go_inv java_inv js_inv
  go_inv="$(scan_go_test_inventory "$root")"
  java_inv="$(scan_java_test_inventory "$root")"
  js_inv="$(scan_js_test_inventory "$root")"

  jq -n \
    --argjson go "$go_inv" \
    --argjson java "$java_inv" \
    --argjson typescript "$js_inv" \
    '{go: $go, java: $java, typescript: $typescript}'
}

detect_test_frameworks() {
  local test_inventory="${1:?TEST_INVENTORY_JSON}"
  echo "$test_inventory" | jq -c '
    [
      (if .go != null and .go.test_files_count > 0 then "go_test" else empty end),
      (if .go != null and .go.packages_with_tests > 0 then "go_test_packages" else empty end),
      (if .java != null and .java.junit_detected then "junit5" else empty end),
      (if .java != null and .java.surefire_configured then "maven_surefire" else empty end),
      (if .java != null and .java.build_tool == "gradle" then "gradle_test" else empty end),
      (if .typescript != null and (.typescript.config_files | map(select(test("vitest"))) | length) > 0 then "vitest" else empty end),
      (if .typescript != null and (.typescript.config_files | map(select(test("jest"))) | length) > 0 then "jest" else empty end),
      (if .typescript != null and .typescript.test_files_count > 0 then "js_unit_tests" else empty end)
    ] | unique
  '
}

collect_packages_without_tests() {
  local test_inventory="${1:?TEST_INVENTORY_JSON}"
  echo "$test_inventory" | jq -c '
    [
      (if .go != null then .go.packages_without_tests // [] else [] end)[],
      (if .typescript != null then .typescript.packages_without_tests // [] else [] end)[]
    ] | unique
  '
}

compute_test_confidence_score() {
  local test_inventory="${1:?TEST_INVENTORY_JSON}"
  local packages_without="${2:?PACKAGES_WITHOUT_JSON}"
  echo "$test_inventory" "$packages_without" | jq -s '
    .[0] as $inv | .[1] as $missing |
    (
      (if $inv.go != null and $inv.go.packages_total > 0
        then ($inv.go.packages_with_tests / $inv.go.packages_total) * 0.35
        elif $inv.go != null and $inv.go.test_files_count > 0 then 0.2
        else 0 end) +
      (if $inv.java != null and $inv.java.junit_detected then 0.2 else 0 end) +
      (if $inv.java != null and $inv.java.test_java_count > 0 then 0.25 else 0 end) +
      (if $inv.java != null and $inv.java.build_tool == "gradle" and $inv.java.test_java_count > 50 then 0.15 else 0 end) +
      (if $inv.typescript != null and $inv.typescript.test_files_count > 0 then 0.2 else 0 end) +
      (if $inv.typescript != null and ($inv.typescript.packages_with_test_script | length) > 0 then 0.1 else 0 end)
    ) as $base |
    (if ($missing | length) > 5 then 0.15 elif ($missing | length) > 0 then 0.05 else 0 end) as $penalty |
    ([$base - $penalty, 0] | max | [., 1] | min)
  '
}

cmd_scan() {
  local work_root="${1:?WORK_ROOT}"
  local repo_root="${2:?REPO_ROOT}"

  if [ ! -d "$repo_root" ]; then
    echo "boundary_scan_error=missing_repo_root path=${repo_root}" >&2
    exit 1
  fi

  local langs go_mods js_mods java_mods shared_libs api_surfaces ci_units
  langs="$(detect_languages "$repo_root")"
  go_mods="$(scan_go_modules "$repo_root")"
  js_mods="$(scan_js_modules "$repo_root")"
  java_mods="$(scan_java_modules "$repo_root")"
  shared_libs="$(find_shared_libraries "$repo_root")"
  api_surfaces="$(find_api_surfaces "$repo_root")"
  ci_units="$(find_ci_deploy_units "$repo_root")"

  [ -n "$go_mods" ] || go_mods='[]'
  [ -n "$js_mods" ] || js_mods='[]'
  [ -n "$java_mods" ] || java_mods='[]'
  [ -n "$shared_libs" ] || shared_libs='[]'
  [ -n "$api_surfaces" ] || api_surfaces='[]'
  [ -n "$ci_units" ] || ci_units='[]'

  local test_inventory test_frameworks packages_without_tests test_confidence_score
  test_inventory="$(scan_test_inventory "$repo_root")"
  test_frameworks="$(detect_test_frameworks "$test_inventory")"
  packages_without_tests="$(collect_packages_without_tests "$test_inventory")"
  test_confidence_score="$(compute_test_confidence_score "$test_inventory" "$packages_without_tests")"

  local cloud_entitlements='{"scan_status":"skipped","reason":"cce_script_missing"}'
  local cce_script="${MONOSPLIT_CCE_SCRIPT:-}"
  if [ -z "$cce_script" ]; then
    if [ -f "$(dirname "${BASH_SOURCE[0]}")/cce-cloud-scan.sh" ]; then
      cce_script="$(dirname "${BASH_SOURCE[0]}")/cce-cloud-scan.sh"
    elif [ -f "${work_root}/scripts/cce-cloud-scan.sh" ]; then
      cce_script="${work_root}/scripts/cce-cloud-scan.sh"
    fi
  fi
  mkdir -p "${work_root}/.work"
  if [ -n "$cce_script" ] && [ -f "$cce_script" ]; then
    cloud_entitlements="$(bash "$cce_script" scan "$repo_root" "$langs" 2>"${work_root}/.work/cce-scan.err" || true)"
    if ! echo "$cloud_entitlements" | jq -e . >/dev/null 2>&1; then
      cloud_entitlements="$(jq -n '{scan_status:"failed",reason:"invalid_cce_json",entitlements:[],summary:{total_entitlements:0,by_provider:{}}}')"
    fi
  fi

  local out="${work_root}/boundary_scan.json"
  jq -n \
    --arg repo_root "$repo_root" \
    --argjson languages "$langs" \
    --argjson go_modules "$go_mods" \
    --argjson js_modules "$js_mods" \
    --argjson java_modules "$java_mods" \
    --argjson shared_libraries "$shared_libs" \
    --argjson api_surfaces "$api_surfaces" \
    --argjson ci_deploy_units "$ci_units" \
    --argjson test_inventory "$test_inventory" \
    --argjson test_frameworks "$test_frameworks" \
    --argjson packages_without_tests "$packages_without_tests" \
    --argjson test_confidence_score "$test_confidence_score" \
    --argjson cloud_entitlements "$cloud_entitlements" \
    --arg script_pack_version "$SCRIPT_PACK_VERSION" \
    '{
      repo_root: $repo_root,
      languages: $languages,
      modules: ($go_modules + $js_modules + $java_modules),
      shared_libraries: $shared_libraries,
      api_surfaces: $api_surfaces,
      ci_deploy_units: $ci_deploy_units,
      test_inventory: $test_inventory,
      test_frameworks: $test_frameworks,
      packages_without_tests: $packages_without_tests,
      test_confidence_score: $test_confidence_score,
      cloud_entitlements: $cloud_entitlements,
      script_pack_version: $script_pack_version
    }' >"$out"

  mirror_note "$work_root" "boundary_scan_json_path" "$out"
  mirror_note "$work_root" "boundary_scan_json_attached" "true"
  mirror_note "$work_root" "test_inventory_attached" "true"
  mirror_note "$work_root" "test_confidence_score" "$(echo "$test_confidence_score" | jq -r .)"
  mirror_note "$work_root" "script_pack_version" "$SCRIPT_PACK_VERSION"
  mirror_note "$work_root" "cloud_entitlements_scan_status" "$(echo "$cloud_entitlements" | jq -r '.scan_status // "unknown"')"
  mirror_note "$work_root" "cloud_entitlements_total" "$(echo "$cloud_entitlements" | jq -r '.summary.total_entitlements // 0')"

  # Compact handoff for analyst stages (session notes / read_notes — not sidecar paths).
  local summary_compact
  summary_compact="$(jq -c '{
    languages,
    test_inventory,
    test_frameworks,
    packages_without_tests,
    test_confidence_score,
    module_count: (.modules | length),
    java_test_java_count: (.test_inventory.java.test_java_count // 0),
    java_recommended_command: (.test_inventory.java.recommended_command // "")
  }' "$out")"
  mirror_note "$work_root" "boundary_scan_summary" "$summary_compact"

  echo "boundary_scan_json_path=${out}"
  echo "boundary_scan_summary_attached=true"
  echo "boundary_scan_ok=true"
  echo "test_confidence_score=$(echo "$test_confidence_score" | jq -r .)"
  echo "script_pack_version=${SCRIPT_PACK_VERSION}"
  cat "$out"
}

case "${1:-}" in
  scan) shift; cmd_scan "$@" ;;
  *)
    echo "usage: boundary-scan.sh scan WORK_ROOT REPO_ROOT" >&2
    exit 1
    ;;
esac
