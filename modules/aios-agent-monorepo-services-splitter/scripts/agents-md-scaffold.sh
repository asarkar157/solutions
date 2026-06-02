#!/usr/bin/env bash
# Generate AGENTS.md (https://agents.md/) from boundary_scan.json + repo introspection.
# Gives coding agents setup, test, and convention context discovered during split analysis.
set -euo pipefail

SCRIPT_PACK_VERSION="${SCRIPT_PACK_VERSION:-20260602.14}"
SANITIZE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/text-sanitize.sh"

readme_blurb() {
  local repo="${1:?REPO_ROOT}"
  local readme="$repo/README.md"
  if [ ! -f "$readme" ]; then
    printf '%s' "_No README.md found — add a project overview here._"
    return 0
  fi
  # First substantive paragraph (skip badges/headings-only lines).
  awk '
    BEGIN { started=0 }
    /^#/ { if (started) exit; next }
    /^[![\[]/ { next }
    /^[[:space:]]*$/ { if (started) exit; next }
    { print; started=1; if (length($0) > 0 && NR > 20) exit }
  ' "$readme" | head -12
}

detect_style_hints() {
  local repo="${1:?REPO_ROOT}"
  local hints=()
  if [ -f "$repo/.editorconfig" ]; then
    hints+=("- EditorConfig: \`.editorconfig\` at repo root")
  fi
  if [ -f "$repo/CONTRIBUTING.md" ]; then
    hints+=("- See \`CONTRIBUTING.md\` for contributor guidelines")
  fi
  if [ -f "$repo/.golangci.yml" ] || [ -f "$repo/.golangci.yaml" ]; then
    hints+=("- Go lint: \`golangci-lint\` (config present)")
  fi
  if [ -f "$repo/checkstyle.xml" ] || [ -f "$repo/config/checkstyle" ]; then
    hints+=("- Java style: Checkstyle configuration detected")
  fi
  if [ -f "$repo/.eslintrc" ] || [ -f "$repo/.eslintrc.js" ] || [ -f "$repo/eslint.config.js" ]; then
    hints+=("- JS/TS lint: ESLint configuration detected")
  fi
  if [ -f "$repo/.prettierrc" ] || [ -f "$repo/.prettierrc.json" ] || [ -f "$repo/prettier.config.js" ]; then
    hints+=("- Formatting: Prettier configuration detected")
  fi
  if [ "${#hints[@]}" -eq 0 ]; then
    hints+=("- Follow patterns in neighboring files; match existing test and package layout")
  fi
  printf '%s\n' "${hints[@]}"
}

detect_setup_commands() {
  local repo="${1:?REPO_ROOT}"
  local scan="${2:?SCAN_JSON}"
  local lines=()

  if [ -f "$repo/go.mod" ]; then
    lines+=("- Install Go deps: \`go mod download\`")
    lines+=("- Build all packages: \`go build ./...\`")
  fi
  if [ -f "$repo/pom.xml" ]; then
    lines+=("- Install/build (skip tests): \`mvn -q -DskipTests package\`")
  fi
  if [ -f "$repo/build.gradle" ] || [ -f "$repo/build.gradle.kts" ] || [ -f "$repo/gradlew" ]; then
    lines+=("- Install/build (skip tests): \`./gradlew build -x test\`")
  fi
  if [ -f "$repo/package.json" ]; then
    if [ -f "$repo/pnpm-lock.yaml" ] || [ -f "$repo/pnpm-workspace.yaml" ]; then
      lines+=("- Install deps: \`pnpm install\`")
    elif [ -f "$repo/yarn.lock" ]; then
      lines+=("- Install deps: \`yarn install\`")
    else
      lines+=("- Install deps: \`npm install\`")
    fi
    if jq -e '.scripts.build' "$repo/package.json" >/dev/null 2>&1; then
      lines+=("- Build: \`$(jq -r '.scripts.build' "$repo/package.json" | sed 's/npm run //')\` (see package.json \`build\` script)")
    fi
  fi
  if [ -f "$repo/Makefile" ]; then
    local mk_targets
    mk_targets="$(grep -E '^[a-zA-Z0-9_.-]+:' "$repo/Makefile" 2>/dev/null | head -8 | cut -d: -f1 | tr '\n' ', ' | sed 's/, $//')"
    if [ -n "$mk_targets" ]; then
      lines+=("- Makefile targets (sample): ${mk_targets}")
    fi
  fi
  if [ "${#lines[@]}" -eq 0 ]; then
    lines+=("- Inspect CI workflows under \`.github/workflows/\` for authoritative setup steps")
  fi
  printf '%s\n' "${lines[@]}"
}

detect_test_commands() {
  local scan="${1:?SCAN_JSON}"
  jq -r '
    .test_inventory as $inv |
    [
      (if $inv.go != null and $inv.go.recommended_command != "" then "- Go: `" + $inv.go.recommended_command + "`" else empty end),
      (if $inv.go != null and $inv.go.coverage_command != "" then "- Go coverage: `" + $inv.go.coverage_command + "`" else empty end),
      (if $inv.java != null and $inv.java.recommended_command != "" then "- Java: `" + $inv.java.recommended_command + "`" else empty end),
      (if $inv.typescript != null and $inv.typescript.recommended_command != "" then "- JS/TS: `" + $inv.typescript.recommended_command + "`" else empty end),
      (if $inv.typescript != null and $inv.typescript.coverage_command != "" then "- JS/TS coverage: `" + $inv.typescript.coverage_command + "`" else empty end)
    ] | .[]
  ' "$scan" 2>/dev/null || true
}

cmd_scaffold() {
  local repo_root="${1:?REPO_ROOT}"
  local scan_path="${2:?BOUNDARY_SCAN_JSON}"
  local out_path="${3:?OUTPUT_AGENTS_MD}"

  if [ ! -f "$scan_path" ]; then
    echo "agents_md_error=missing_boundary_scan" >&2
    return 1
  fi

  local langs module_count test_score frameworks ci_list shared_libs api_count
  langs="$(jq -r '.languages | join(", ")' "$scan_path")"
  module_count="$(jq -r '.modules | length' "$scan_path")"
  test_score="$(jq -r '.test_confidence_score' "$scan_path")"
  frameworks="$(jq -r '.test_frameworks | join(", ")' "$scan_path")"
  ci_list="$(jq -r '.ci_deploy_units[]?.path // empty' "$scan_path" | sed "s|^${repo_root}/||" | head -10)"
  shared_libs="$(jq -r '.shared_libraries[]?.path // empty' "$scan_path" | tr '\n' ', ' | sed 's/, $//')"
  api_count="$(jq -r '.api_surfaces | length' "$scan_path")"

  local readme overview setup style tests analyst_extra=""
  readme="$(readme_blurb "$repo_root")"
  overview="$readme"
  if [ -f "${scan_path%/*}/notes.json" ]; then
    analyst_extra="$(jq -r '.agents_md_analyst_sections // empty' "${scan_path%/*}/notes.json" 2>/dev/null || true)"
  fi
  if [ -n "$analyst_extra" ] && [ -f "$SANITIZE_SCRIPT" ]; then
    analyst_extra="$(printf '%s' "$analyst_extra" | bash "$SANITIZE_SCRIPT")"
  fi

  {
    cat <<EOF
# AGENTS.md

Agent instructions for this repository. Generated during Guild monorepo split analysis
(script pack ${SCRIPT_PACK_VERSION}). Format: [agents.md](https://agents.md/).

## Project overview

${overview}

- **Languages detected:** ${langs}
- **Modules / packages scanned:** ${module_count}
- **Test confidence score:** ${test_score} (0–1, from unit-test inventory)
- **Test frameworks:** ${frameworks:-unknown}
EOF
    if [ -n "$shared_libs" ]; then
      echo "- **Shared library paths:** ${shared_libs}"
    fi
    if [ "$api_count" != "0" ]; then
      echo "- **API surface hints:** ${api_count} candidate HTTP/OpenAPI paths (see \`boundary_scan.json\`)"
    fi

    cat <<'EOF'

## Setup commands

EOF
    detect_setup_commands "$repo_root" "$scan_path"

    cat <<'EOF'

## Testing instructions

Run the language-appropriate suite before opening PRs. Prefer the same commands CI uses.

EOF
    detect_test_commands "$scan_path"
    if [ -n "$ci_list" ]; then
      echo ""
      echo "CI workflow files to mirror locally:"
      while IFS= read -r wf; do
        [ -n "$wf" ] && echo "- \`${wf}\`"
      done <<<"$ci_list"
    fi

    cat <<EOF

- Fix failing tests before merge; do not disable tests to land split/refactor work.
- Packages without unit tests (high coupling cut risk): see \`packages_without_tests\` in \`docs/architecture/coupling-matrix.json\`.

## Code style and conventions

EOF
    detect_style_hints "$repo_root"

    cat <<'EOF'

## Monorepo / split context

This repo was analyzed for service extraction. Architecture artifacts live under `docs/architecture/`:

- `service-catalog.yaml` — proposed target services
- `migration-phases.md` — strangler-fig ordering
- `bounded-context-map.mermaid` — DDD context map
- `coupling-matrix.json` — scan output including `test_inventory`

When extracting a service, keep **unit tests co-located** with the code you move and add contract tests at new HTTP/gRPC boundaries.

## PR instructions

- Open PRs against the default branch; use feature branches (`guild/split-*` for Guild-generated work).
- Include test evidence for touched packages (CI log snippet or local command output).
- Do not push directly to the default branch.

EOF
    if [ -n "$analyst_extra" ]; then
      cat <<EOF

## Domain analysis (analyst)

${analyst_extra}

EOF
    fi
  } >"$out_path"

  echo "agents_md_path=${out_path}"
  echo "agents_md_produced=true"
}

case "${1:-}" in
  scaffold) shift; cmd_scaffold "$@" ;;
  *)
    echo "usage: agents-md-scaffold.sh scaffold REPO_ROOT BOUNDARY_SCAN_JSON OUTPUT_AGENTS_MD" >&2
    exit 1
    ;;
esac
