#!/usr/bin/env bash
# Scaffold services/<name>/ skeletons from service-catalog.yaml with language-appropriate test stubs.
set -euo pipefail

SCRIPT_PACK_VERSION="${SCRIPT_PACK_VERSION:-20260602.4}"

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

service_dir_from_path() {
  local path="${1:-}"
  path="${path%/}"
  if [ -z "$path" ]; then
    return 1
  fi
  basename "$path"
}

slug_from_service_name() {
  local name="${1:?}"
  name="${name%-svc}"
  printf '%s' "$name"
}

# Emit TSV lines: service_dir<TAB>display_name (deduplicated)
catalog_list_entries() {
  local catalog_path="${1:?CATALOG_PATH}"
  if [ ! -f "$catalog_path" ]; then
    return 0
  fi
  local tmp
  tmp="$(mktemp)"

  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*-[[:space:]]*\{ ]] || continue
    local name path dir
    name="$(printf '%s' "$line" | sed -E 's/.*name:[[:space:]]*([^,}]+).*/\1/' | tr -d ' "')"
    path="$(printf '%s' "$line" | sed -E 's/.*repo_path:[[:space:]]*([^,}]+).*/\1/' | tr -d ' "')"
    if [ "$path" = "$line" ] || [ -z "$path" ]; then
      path="$(printf '%s' "$line" | sed -E 's/^[^{]*\{[^}]*path:[[:space:]]*([^,}]+).*/\1/' | tr -d ' "')"
    fi
    [ -n "$name" ] || continue
    if [ -n "$path" ]; then
      dir="$(service_dir_from_path "$path")" || dir="$(slug_from_service_name "$name")"
    else
      dir="$(slug_from_service_name "$name")"
    fi
    printf '%s\t%s\n' "$dir" "$name" >>"$tmp"
  done <"$catalog_path"

  awk '
    /^[[:space:]]*-[[:space:]]*name:/ {
      if (name != "") emit()
      if ($2 == "name:") {
        name = $3
      } else {
        name = $2
        sub(/^name:/, "", name)
      }
      gsub(/"/, "", name)
      path = ""
      next
    }
    /^[[:space:]]*(path|repo_path):/ {
      path = $2
      gsub(/"/, "", path)
      next
    }
    END { if (name != "") emit() }
    function emit(   dir, n, parts) {
      if (name == "" || name == "name:") return
      if (path != "") {
        sub(/\/$/, "", path)
        n = split(path, parts, "/")
        dir = parts[n]
      } else {
        dir = name
        sub(/-svc$/, "", dir)
      }
      print dir "\t" name
    }
  ' "$catalog_path" >>"$tmp"

  awk -F'\t' 'NF >= 2 && !seen[$1]++ { print $1 "\t" $2 }' "$tmp"
  rm -f "$tmp"
}

detect_scaffold_languages() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="${2:?REPO_DIR}"
  local scan="${work_root}/boundary_scan.json"
  local catalog_path="${3:-}"
  local found=0

  if [ -f "$scan" ]; then
    jq -r '.languages[]?' "$scan" 2>/dev/null || true
    return 0
  fi

  if [ -n "$catalog_path" ] && [ -f "$catalog_path" ]; then
    if grep -qiE 'language:[[:space:]]*java' "$catalog_path"; then
      echo java
      found=1
    fi
    if grep -qiE 'language:[[:space:]]*go' "$catalog_path"; then
      echo go
      found=1
    fi
    if grep -qiE 'language:[[:space:]]*(typescript|javascript)' "$catalog_path"; then
      echo typescript
      found=1
    fi
    if [ "$found" -eq 1 ]; then
      return 0
    fi
  fi

  if [ -f "$repo_dir/go.mod" ]; then echo go; fi
  if [ -f "$repo_dir/pom.xml" ] || [ -f "$repo_dir/build.gradle" ] || [ -f "$repo_dir/build.gradle.kts" ]; then echo java; fi
  if [ -f "$repo_dir/package.json" ]; then echo typescript; fi
}

detect_build_tool() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="${2:?REPO_DIR}"
  local catalog_path="${3:-}"

  if [ -n "$catalog_path" ] && [ -f "$catalog_path" ]; then
    if grep -qiE 'build_tool:[[:space:]]*gradle' "$catalog_path"; then
      echo gradle
      return 0
    fi
    if grep -qiE 'build_tool:[[:space:]]*maven' "$catalog_path"; then
      echo maven
      return 0
    fi
  fi
  if [ -f "$repo_dir/settings.gradle.kts" ] || [ -f "$repo_dir/settings.gradle" ] || [ -f "$repo_dir/build.gradle.kts" ]; then
    echo gradle
    return 0
  fi
  if [ -f "$repo_dir/pom.xml" ]; then
    echo maven
    return 0
  fi
  echo unknown
}

detect_js_test_framework() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="${2:?REPO_DIR}"
  local scan="${work_root}/boundary_scan.json"

  if [ -f "$scan" ] && jq -e '.test_frameworks | index("vitest")' "$scan" >/dev/null 2>&1; then
    echo vitest
    return 0
  fi
  if [ -f "$scan" ] && jq -e '.test_frameworks | index("jest")' "$scan" >/dev/null 2>&1; then
    echo jest
    return 0
  fi
  if [ -f "$repo_dir/vitest.config.ts" ] || [ -f "$repo_dir/vitest.config.js" ]; then
    echo vitest
    return 0
  fi
  echo jest
}

scaffold_go_tests() {
  local svc_dir="${1:?}"
  local name="${2:?}"
  [ -f "$svc_dir/main_test.go" ] && return 0
  cat >"$svc_dir/main_test.go" <<EOF
package main

import "testing"

// Table-driven unit tests — run: go test ./... -race -count=1
func TestScaffoldHealth(t *testing.T) {
	tests := []struct {
		name string
		want bool
	}{
		{"service scaffold loads", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.want != true {
				t.Errorf("expected scaffold health check to pass")
			}
		})
	}
}
EOF
}

scaffold_java_tests() {
  local svc_dir="${1:?}"
  local name="${2:?}"
  local pkg_path="src/test/java/com/guild/${name//-/_}"
  mkdir -p "$svc_dir/$pkg_path"
  local class_name="ScaffoldTest"
  [ -f "$svc_dir/$pkg_path/${class_name}.java" ] && return 0
  cat >"$svc_dir/$pkg_path/${class_name}.java" <<EOF
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** JUnit 5 unit stub — run: mvn test or ./gradlew test */
class ${class_name} {
    @Test
    void scaffoldLoads() {
        assertTrue(true, "${name} scaffold is present");
    }
}
EOF
}

scaffold_java_gradle() {
  local svc_dir="${1:?}"
  local name="${2:?}"
  [ -f "$svc_dir/build.gradle.kts" ] && return 0
  cat >"$svc_dir/build.gradle.kts" <<'EOF'
plugins {
    `java-library`
    jacoco
}

description = "Guild split scaffold — SERVICE_NAME"

dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
}

tasks.test {
    useJUnitPlatform()
    finalizedBy(tasks.jacocoTestReport)
}
EOF
  sed "s/SERVICE_NAME/${name}/g" "$svc_dir/build.gradle.kts" >"${svc_dir}/build.gradle.kts.tmp" \
    && mv "${svc_dir}/build.gradle.kts.tmp" "$svc_dir/build.gradle.kts"
}

scaffold_ts_tests() {
  local svc_dir="${1:?}"
  local name="${2:?}"
  local framework="${3:?vitest}"
  local test_file="$svc_dir/${name}.test.ts"
  [ -f "$test_file" ] && return 0

  if [ "$framework" = "vitest" ]; then
    cat >"$test_file" <<EOF
import { describe, it, expect } from 'vitest';

// Unit stub — run: pnpm test --filter ${name} or npm test
describe('${name}', () => {
  it('scaffold loads', () => {
    expect(true).toBe(true);
  });
});
EOF
    return 0
  fi

  cat >"$test_file" <<EOF
/** Jest unit stub — run: npm test */
describe('${name}', () => {
  it('scaffold loads', () => {
    expect(true).toBe(true);
  });
});
EOF
}

write_service_readme() {
  local svc_dir="${1:?}"
  local dir_name="${2:?}"
  local display_name="${3:?}"
  cat >"$svc_dir/README.md" <<EOF
# ${display_name}

Scaffolded by Guild \`monorepo-services-split-extract\` (script pack ${SCRIPT_PACK_VERSION}).

## Purpose

Target microservice at \`services/${dir_name}/\` per approved \`service-catalog.yaml\`.

## Ownership

- Independent deploy unit (container + CI stub)
- Own API surface and data ownership per service catalog entry
- **Unit tests required** before merge — JUnit 5 / Go test / Vitest stub included

## Test gate

Run language-appropriate tests for this service before approving the extract PR:

- Java/Gradle: \`./gradlew :services:${dir_name}:test\`
- Go: \`go test ./services/${dir_name}/... -race -count=1\`
- TypeScript: \`pnpm test\` scoped to this package
EOF
}

gradle_include_block_file() {
  local out="${1:?OUT}"
  local marker_begin="${2:?BEGIN}"
  local marker_end="${3:?END}"
  local services_root="${4:?SERVICES_ROOT}"
  {
    echo "$marker_begin"
    find "$services_root" -mindepth 1 -maxdepth 1 -type d | sort | while read -r svc_dir; do
      local name
      name="$(basename "$svc_dir")"
      echo "include(\":services:${name}\")"
      echo "project(\":services:${name}\").projectDir = file(\"services/${name}\")"
    done
    echo "$marker_end"
  } >"$out"
}

merge_gradle_include_block() {
  local settings_file="${1:?SETTINGS}"
  local marker_begin="${2:?BEGIN}"
  local marker_end="${3:?END}"
  local block_file="${4:?BLOCK}"
  if grep -qF "$marker_begin" "$settings_file"; then
    awk -v begin="$marker_begin" -v end="$marker_end" '
      $0 ~ begin { skip=1; next }
      $0 ~ end { skip=0; next }
      skip==0 { print }
    ' "$settings_file" >"${settings_file}.tmp"
    cat "${settings_file}.tmp" "$block_file" >"$settings_file"
    rm -f "${settings_file}.tmp"
    return 0
  fi
  cat "$block_file" >>"$settings_file"
}

wire_gradle_settings() {
  local repo_dir="${1:?REPO_DIR}"
  local services_root="${2:?SERVICES_ROOT}"
  local settings_kts="$repo_dir/settings.gradle.kts"
  local settings_groovy="$repo_dir/settings.gradle"
  local block_file
  block_file="$(mktemp)"

  if [ -f "$settings_kts" ]; then
    gradle_include_block_file "$block_file" \
      "// BEGIN guild-split-scaffold-includes" \
      "// END guild-split-scaffold-includes" \
      "$services_root"
    merge_gradle_include_block "$settings_kts" \
      "// BEGIN guild-split-scaffold-includes" \
      "// END guild-split-scaffold-includes" \
      "$block_file"
    rm -f "$block_file"
    return 0
  fi

  if [ -f "$settings_groovy" ]; then
    gradle_include_block_file "$block_file" \
      "# BEGIN guild-split-scaffold-includes" \
      "# END guild-split-scaffold-includes" \
      "$services_root"
    merge_gradle_include_block "$settings_groovy" \
      "# BEGIN guild-split-scaffold-includes" \
      "# END guild-split-scaffold-includes" \
      "$block_file"
  fi
  rm -f "$block_file"
}

validate_scaffold_layout() {
  local work_root="${1:?WORK_ROOT}"
  local services_root="${2:?SERVICES_ROOT}"
  local langs="${3:?}"
  local errors=0
  local dir

  if [ ! -d "$services_root" ]; then
    mirror_note "$work_root" "scaffold_layout_validated" "false"
    mirror_note "$work_root" "scaffold_validation_error" "missing_services_root"
    echo "scaffold_validation_error=missing_services_root" >&2
    return 1
  fi

  shopt -s nullglob
  local dirs=("$services_root"/*)
  shopt -u nullglob
  if [ "${#dirs[@]}" -eq 0 ]; then
    mirror_note "$work_root" "scaffold_layout_validated" "false"
    mirror_note "$work_root" "scaffold_validation_error" "no_service_directories"
    echo "scaffold_validation_error=no_service_directories" >&2
    return 1
  fi

  for dir in "${dirs[@]}"; do
    [ -d "$dir" ] || continue
    local name
    name="$(basename "$dir")"
    if [ ! -f "$dir/README.md" ] || [ "$(wc -c <"$dir/README.md" | tr -d ' ')" -lt 120 ]; then
      echo "scaffold_validation_error=readme_too_short service=${name}" >&2
      errors=$((errors + 1))
    fi
    if [ ! -f "$dir/Dockerfile" ]; then
      echo "scaffold_validation_error=missing_dockerfile service=${name}" >&2
      errors=$((errors + 1))
    fi
    if echo "$langs" | grep -q java; then
      if ! find "$dir" -path '*/src/test/java/*.java' -print -quit | grep -q .; then
        echo "scaffold_validation_error=missing_java_test service=${name}" >&2
        errors=$((errors + 1))
      fi
      if [ ! -f "$dir/build.gradle.kts" ] && [ ! -f "$dir/build.gradle" ] && [ ! -f "$dir/pom.xml" ]; then
        echo "scaffold_validation_error=missing_java_build_file service=${name}" >&2
        errors=$((errors + 1))
      fi
    fi
    if echo "$langs" | grep -q go; then
      if [ ! -f "$dir/main_test.go" ]; then
        echo "scaffold_validation_error=missing_go_test service=${name}" >&2
        errors=$((errors + 1))
      fi
    fi
    if echo "$langs" | grep -q typescript; then
      if ! find "$dir" -name '*.test.ts' -print -quit | grep -q .; then
        echo "scaffold_validation_error=missing_ts_test service=${name}" >&2
        errors=$((errors + 1))
      fi
    fi
  done

  if [ "$errors" -gt 0 ]; then
    mirror_note "$work_root" "scaffold_layout_validated" "false"
    mirror_note "$work_root" "scaffold_validation_error" "count=${errors}"
    echo "scaffold_validation_error=count=${errors}" >&2
    return 1
  fi

  mirror_note "$work_root" "scaffold_layout_validated" "true"
  return 0
}

scaffold_one_service() {
  local svc_dir="${1:?}"
  local dir_name="${2:?}"
  local display_name="${3:?}"
  local langs="${4:?}"
  local js_framework="${5:?}"

  mkdir -p "$svc_dir"
  write_service_readme "$svc_dir" "$dir_name" "$display_name"

  if [ ! -f "$svc_dir/Dockerfile" ]; then
    cat >"$svc_dir/Dockerfile" <<'EOF'
# TODO: replace with language-specific base image
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY . .
CMD ["echo", "replace with service entrypoint"]
EOF
  fi

  if [ ! -f "$svc_dir/.github-workflow-stub.yml" ]; then
    cat >"$svc_dir/.github-workflow-stub.yml" <<EOF
# CI stub — move to .github/workflows/${dir_name}.yml when ready
name: ${dir_name}
on:
  push:
    paths:
      - services/${dir_name}/**
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Unit tests (language-specific)
        run: echo "Run go test / ./gradlew test / pnpm test for ${dir_name}"
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Build ${dir_name}"
EOF
  fi

  if echo "$langs" | grep -q go; then
    scaffold_go_tests "$svc_dir" "$dir_name"
  fi
  if echo "$langs" | grep -q java; then
    scaffold_java_gradle "$svc_dir" "$dir_name"
    scaffold_java_tests "$svc_dir" "$dir_name"
  fi
  if echo "$langs" | grep -q typescript; then
    scaffold_ts_tests "$svc_dir" "$dir_name" "$js_framework"
  fi
}

cmd_scaffold() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="${2:?REPO_DIR}"
  local catalog_path="${3:-$work_root/service-catalog.yaml}"

  if [ ! -d "$repo_dir" ]; then
    echo "scaffold_error=missing_repo_dir" >&2
    exit 1
  fi
  if [ ! -f "$catalog_path" ]; then
    mirror_note "$work_root" "scaffold_layout_validated" "false"
    mirror_note "$work_root" "scaffold_validation_error" "missing_catalog"
    echo "scaffold_error=missing_catalog path=${catalog_path}" >&2
    exit 1
  fi

  local langs js_framework build_tool
  langs="$(detect_scaffold_languages "$work_root" "$repo_dir" "$catalog_path" | tr '\n' ' ' | xargs)"
  js_framework="$(detect_js_test_framework "$work_root" "$repo_dir")"
  build_tool="$(detect_build_tool "$work_root" "$repo_dir" "$catalog_path")"

  local services_root="$repo_dir/services"
  mkdir -p "$services_root"

  local count=0
  local entry dir_name display_name
  while IFS=$'\t' read -r dir_name display_name; do
    [ -n "$dir_name" ] || continue
    [ -n "$display_name" ] || display_name="$dir_name"
    scaffold_one_service "$services_root/$dir_name" "$dir_name" "$display_name" "$langs" "$js_framework"
    count=$((count + 1))
  done < <(catalog_list_entries "$catalog_path")

  if [ "$count" -eq 0 ]; then
    mirror_note "$work_root" "scaffold_layout_validated" "false"
    mirror_note "$work_root" "scaffold_validation_error" "no_catalog_entries"
    echo "scaffold_error=no_catalog_entries" >&2
    exit 1
  fi

  if [ "$build_tool" = "gradle" ]; then
    wire_gradle_settings "$repo_dir" "$services_root"
  fi

  if ! validate_scaffold_layout "$work_root" "$services_root" "$langs"; then
    exit 1
  fi

  mirror_note "$work_root" "scaffold_layout_created" "true"
  mirror_note "$work_root" "scaffold_service_count" "$count"
  mirror_note "$work_root" "per_service_test_strategy_documented" "true"
  echo "scaffold_layout_created=true"
  echo "scaffold_layout_validated=true"
  echo "scaffold_service_count=${count}"
  echo "per_service_test_strategy_documented=true"
}

case "${1:-}" in
  scaffold) shift; cmd_scaffold "$@" ;;
  list-entries) shift; catalog_list_entries "${1:?CATALOG}" ;;
  *)
    echo "usage: scaffold-services.sh scaffold|list-entries ..." >&2
    exit 1
    ;;
esac
