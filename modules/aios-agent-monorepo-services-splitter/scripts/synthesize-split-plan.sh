#!/usr/bin/env bash
# Deterministic split plan: catalog, migration phases, mermaid, audience docs from scan + matrix.
set -euo pipefail

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

write_glossary() {
  local arch_dir="${1:?ARCH_DIR}"
  cat >"${arch_dir}/glossary.md" <<'EOF'
# Glossary

| Term | Meaning |
|------|---------|
| **Bounded context** | A part of the system with its own model and language; changes inside it should not leak confusing terms to other parts. |
| **Strangler fig** | Migrate gradually: new behavior grows beside the old until the old can be retired. |
| **BOM (Bill of Materials)** | A Maven/Gradle artifact that pins compatible versions of related libraries. |
| **Hub module** | A library many other modules depend on; extract or change it last. |
| **Contract test** | Tests that verify an API between two components stays compatible. |
EOF
}

write_for_developers() {
  local arch_dir="${1:?ARCH_DIR}"
  local test_cmd="${2:-}"
  local hub="${3:-}"
  cat >"${arch_dir}/for-developers.md" <<EOF
# For developers (new to this repo)

## What this guidance PR is

Architecture notes from an automated scan of this repository. Use them to understand how the codebase is grouped before any split work.

## Your next 3 steps

1. Read the [architecture README](README.md) (5 minutes).
2. Run baseline tests: \`${test_cmd:-see AGENTS.md}\`
3. Explore the **hub module** first: \`${hub:-see service-catalog.yaml}\`

## Do not break

- Do not change public APIs in the hub module without coordinating all dependents.
- Add or extend unit tests before moving code across module boundaries.

<!-- LLM enrichment may extend sections below -->
EOF
}

write_for_tech_leads() {
  local arch_dir="${1:?ARCH_DIR}"
  cat >"${arch_dir}/for-tech-leads.md" <<'EOF'
# For tech leads (planning delivery)

## Migration stance

Follow `migration-phases.md` in order. Each phase should end with green CI on the paths you touched.

## Gates before extraction

- Baseline test command green on the default branch (or documented environment constraint).
- No extraction through modules listed in `packages_without_tests` without a tests-first sub-phase.

## Your next 3 steps

1. Agree on `repo_archetype` and service/module groups in `service-catalog.yaml`.
2. Assign an owner per group for Phase 0 test remediation (if needed).
3. Schedule contract tests at any new publish or HTTP boundary.

<!-- LLM enrichment may extend sections below -->
EOF
}

write_for_architects() {
  local arch_dir="${1:?ARCH_DIR}"
  local hub="${2:-}"
  cat >"${arch_dir}/for-architects.md" <<EOF
# For architects (boundaries and risk)

## Evidence-first review

- **Dependency graph:** \`coupling-matrix.json\` (machine-generated from build files).
- **Hub module:** \`${hub:-unknown}\` — highest inbound coupling; treat as shared kernel.
- **Cloud / outbound coupling:** see \`cce_summary\` in scan notes and optional \`cce-*.json\` artifacts.

## Anti-patterns to avoid

- Declaring network microservices for pure library modules (JAR/npm packages).
- Cutting through the hub without a versioned client SDK or BOM strategy.

## Your next 3 steps

1. Validate clusters in \`service-catalog.yaml\` against \`coupling-matrix.json\`.
2. Confirm \`repo_archetype\` matches how you ship software (library vs runnable services).
3. Record ADR references in PR comments if you disagree with a proposed group.

<!-- LLM enrichment may extend sections below -->
EOF
}

write_architecture_readme() {
  local arch_dir="${1:?ARCH_DIR}"
  local archetype="${2:-mixed}"
  local mod_count="${3:-0}"
  local hub="${4:-}"
  cat >"${arch_dir}/README.md" <<EOF
# Monorepo split analysis — start here

## At a glance

- **Repository archetype:** \`${archetype}\`
- **Modules scanned:** ${mod_count}
- **Hub module (highest fan-in):** \`${hub:-n/a}\`

## Choose your path

| I am… | Read next |
|-------|-----------|
| New to the codebase | [for-developers.md](for-developers.md) |
| Planning migration sprints | [for-tech-leads.md](for-tech-leads.md) |
| Reviewing boundaries and risk | [for-architects.md](for-architects.md) |

## Artifacts in this folder

| File | Purpose |
|------|---------|
| \`service-catalog.yaml\` | Proposed groups (machine-generated structure) |
| \`coupling-matrix.json\` | Module dependencies and extraction order hint |
| \`migration-phases.md\` | Phased plan |
| \`bounded-context-map.mermaid\` | Visual overview |
| \`glossary.md\` | Plain-language terms |

See also repo-root \`AGENTS.md\` for build and test commands.
EOF
}

write_mermaid() {
  local arch_dir="${1:?ARCH_DIR}"
  local matrix_path="${2:?MATRIX}"
  local hub
  hub="$(jq -r '.hub_module // "core"' "$matrix_path")"
  {
    echo "flowchart TB"
    echo "  subgraph hub[\"Hub: ${hub}\"]"
    echo "    H[${hub}]"
    echo "  end"
    jq -r '.modules[] | select(.path != "'"$hub"'") | "  \(.path | gsub("-"; "_"))[\(.path)]"' "$matrix_path" 2>/dev/null | head -20
    echo "  H --> $(jq -r '[.modules[] | select(.inbound_edges > 0) | .path][0:5] | join("\n  H --> ")' "$matrix_path" 2>/dev/null || true)"
  } >"${arch_dir}/bounded-context-map.mermaid"
}

write_migration_phases() {
  local arch_dir="${1:?ARCH_DIR}"
  local archetype="${2:-library_monorepo}"
  local matrix_path="${3:?MATRIX}"
  if [ "$archetype" = "service_monorepo" ]; then
    cat >"${arch_dir}/migration-phases.md" <<'EOF'
# Migration phases (service monorepo)

## Phase 0 — Tests and CI confidence

Add or stabilize unit tests on high-coupling paths. Document baseline test command in AGENTS.md.

## Phase 1 — Contract-first boundaries

Publish OpenAPI/proto for each proposed service boundary before moving code.

## Phase 2 — Strangler extraction

Move implementations per `service-catalog.yaml` with green unit + contract tests per group.

## Phase 3 — Data and runtime decomposition

Split shared databases and deploy units only after traffic routes through new service facades.
EOF
  else
    cat >"${arch_dir}/migration-phases.md" <<'EOF'
# Migration phases (library / multi-module repo)

## Phase 0 — Tests and toolchain

Ensure Java/Go/Node toolchain matches repo requirements; `./gradlew test` or equivalent green.

## Phase 1 — Stabilize shared kernel

Lock APIs for the hub module; publish SNAPSHOT or document internal-only status.

## Phase 2 — Extract leaf modules

Publish independent artifacts for modules with low inbound coupling (see `coupling-matrix.json` extraction_order).

## Phase 3 — Framework and integration modules

Extract adapters (Spring, Reactor, etc.) after core pattern libraries have stable coordinates.

## Phase 4 — BOM and consumer alignment

Update BOM and downstream consumer version pins; run compatibility tests.
EOF
  fi
  echo "" >>"${arch_dir}/migration-phases.md"
  echo "Suggested extraction order (from coupling scan):" >>"${arch_dir}/migration-phases.md"
  jq -r '.extraction_order[]? | "- \(.)"' "$matrix_path" 2>/dev/null >>"${arch_dir}/migration-phases.md" || true
}

write_service_catalog() {
  local arch_dir="${1:?ARCH_DIR}"
  local archetype="${2:-library_monorepo}"
  local matrix_path="${3:?MATRIX}"
  local max_groups="${4:-12}"
  local hub
  hub="$(jq -r '.hub_module // ""' "$matrix_path")"

  {
    echo "# Proposed groups — generated from dependency scan"
    echo "repo_archetype: ${archetype}"
    echo "services:"
  } >"${arch_dir}/service-catalog.yaml"

  jq -r --arg arch "$archetype" --arg hub "$hub" --argjson max "$max_groups" '
    def kind_for:
      if $arch == "service_monorepo" then "runnable_service" else "library_module" end;
    .modules | sort_by(-.inbound_edges) | .[0:$max] | .[] |
    "- name: \(.path)\n  kind: \(kind_for)\n  modules: [\(.path)]\n  depends_on: \(.depends_on // [])\n  never_extract: \(if .path == $hub or .inbound_edges > 5 then true else false end)\n  summary_plain: \"Group centered on \(.path) (inbound_edges=\(.inbound_edges)).\"\n  developer_notes: \"Run scoped tests for \(.path) before API changes.\"\n  tech_lead_notes: \"Schedule after hub stabilization when never_extract is true.\"\n  architect_notes: \"See coupling-matrix.json for edge evidence.\""
  ' "$matrix_path" >>"${arch_dir}/service-catalog.yaml"
}

write_testing_strategy() {
  local arch_dir="${1:?ARCH_DIR}"
  local scan_path="${2:?SCAN}"
  cat >"${arch_dir}/testing-strategy.md" <<'EOF'
# Testing strategy (from scan)

Per-ecosystem commands detected during boundary scan. Run these before and after each extraction phase.
EOF
  jq -r '
    .test_inventory // {} | to_entries[] |
    "- **\(.key)**: recommended `\(.value.recommended_command // "see AGENTS.md")` (confidence: \(.value.confidence // "n/a"))"
  ' "$scan_path" 2>/dev/null >>"${arch_dir}/testing-strategy.md" || true
  if jq -e '(.packages_without_tests // []) | length > 0' "$scan_path" >/dev/null 2>&1; then
    echo "" >>"${arch_dir}/testing-strategy.md"
    echo "## Packages without tests (remediate in Phase 0)" >>"${arch_dir}/testing-strategy.md"
    jq -r '.packages_without_tests[]? | "- \(.)"' "$scan_path" >>"${arch_dir}/testing-strategy.md"
  fi
}

cmd_synthesize() {
  local work_root="${1:?WORK_ROOT}"
  local max_groups="${MAX_RECOMMENDED_SERVICES:-12}"

  local scan="${work_root}/boundary_scan.json"
  if [ ! -f "$scan" ]; then
    echo "plan_validation_failed=true"
    echo "deterministic_plan_produced=false"
    exit 1
  fi

  local matrix="${work_root}/coupling-matrix.json"
  if [ ! -f "$matrix" ] && [ -f "${work_root}/scripts/build-coupling-matrix.sh" ]; then
    bash "${work_root}/scripts/build-coupling-matrix.sh" build "$scan" "$matrix"
  fi

  local archetype
  archetype="$(jq -r '.repo_archetype // "mixed"' "$scan")"
  if [ -f "${work_root}/scripts/detect-repo-archetype.sh" ] && [ "$archetype" = "null" ] || [ -z "$archetype" ]; then
    archetype="$(bash "${work_root}/scripts/detect-repo-archetype.sh" detect "$scan" 2>/dev/null | sed -n 's/^repo_archetype=//p' | head -1)"
  fi
  [ -n "$archetype" ] && [ "$archetype" != "null" ] || archetype="mixed"

  local mod_count hub test_cmd
  mod_count="$(jq -r '.modules | length' "$scan")"
  hub="$(jq -r '.hub_module // ""' "$matrix" 2>/dev/null || true)"
  test_cmd="$(jq -r '.test_inventory.java.recommended_command // .test_inventory.go.recommended_command // "see AGENTS.md"' "$scan")"

  if [ "$mod_count" -eq 0 ]; then
    echo "plan_validation_failed=true"
    echo "plan_validation_errors=zero_modules"
    echo "deterministic_plan_produced=false"
    exit 1
  fi

  mkdir -p "${work_root}/docs/architecture"
  local arch="${work_root}/docs/architecture"

  write_service_catalog "$arch" "$archetype" "$matrix" "$max_groups"
  write_testing_strategy "$arch" "$scan"
  write_migration_phases "$arch" "$archetype" "$matrix"
  write_mermaid "$arch" "$matrix"
  write_glossary "$arch"
  write_for_developers "$arch" "$test_cmd" "$hub"
  write_for_tech_leads "$arch"
  write_for_architects "$arch" "$hub"
  write_architecture_readme "$arch" "$archetype" "$mod_count" "$hub"

  cat >"${arch}/monorepo-split-analysis.md" <<EOF
# Monorepo split analysis (index)

Start at [README.md](README.md).

Machine-readable catalog: \`service-catalog.yaml\`. Dependency evidence: \`coupling-matrix.json\`.
EOF

  if [ -f "${work_root}/scripts/text-sanitize.sh" ]; then
    for f in "${arch}"/*.md "${arch}"/*.yaml "${arch}"/*.mermaid; do
      [ -f "$f" ] && bash "${work_root}/scripts/text-sanitize.sh" file "$f" || true
    done
  fi

  cp "${arch}/service-catalog.yaml" "${work_root}/service-catalog.yaml"
  if [ "$matrix" != "${work_root}/coupling-matrix.json" ]; then
    cp "$matrix" "${work_root}/coupling-matrix.json"
  fi
  if [ "$matrix" != "${arch}/coupling-matrix.json" ]; then
    cp "$matrix" "${arch}/coupling-matrix.json"
  fi

  mirror_note "$work_root" "deterministic_plan_produced" "true"
  mirror_note "$work_root" "plan_ok" "true"
  mirror_note "$work_root" "repo_archetype" "$archetype"

  echo "deterministic_plan_produced=true"
  echo "plan_ok=true"
  echo "repo_archetype=${archetype}"
  echo "stage_summary:synthesize-split-plan=ok"
}

case "${1:-}" in
  synthesize) shift; cmd_synthesize "$@" ;;
  *)
    echo "usage: synthesize-split-plan.sh synthesize WORK_ROOT" >&2
    exit 1
    ;;
esac
