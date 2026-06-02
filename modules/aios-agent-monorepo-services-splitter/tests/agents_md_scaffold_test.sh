#!/usr/bin/env bash
# Unit-style test for agents-md-scaffold.sh against synthetic scan output.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAFFOLD="${ROOT}/scripts/agents-md-scaffold.sh"
WORK="$(mktemp -d)"
REPO="${WORK}/sample-repo"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$REPO/pkg/core"
cat >"$REPO/README.md" <<'EOF'
# Sample Monorepo

A synthetic repo used to validate AGENTS.md scaffolding during split analysis.

## Purpose

Demonstrates multi-language layout for boundary scan and agent onboarding docs.
EOF
cat >"$REPO/go.mod" <<'EOF'
module example.com/monorepo

go 1.22
EOF
cat >"$REPO/pkg/core/core.go" <<'EOF'
package core

func Hello() string { return "hello" }
EOF
cat >"$REPO/.editorconfig" <<'EOF'
root = true
[*]
indent_style = space
EOF

cat >"$WORK/boundary_scan.json" <<'EOF'
{
  "languages": ["go"],
  "modules": [{"path": "pkg/core", "language": "go"}],
  "test_confidence_score": 0.75,
  "test_frameworks": ["go_test"],
  "shared_libraries": [{"path": "pkg/core"}],
  "api_surfaces": [],
  "ci_deploy_units": [{"path": ".github/workflows/ci.yml"}],
  "test_inventory": {
    "go": {
      "recommended_command": "go test ./...",
      "coverage_command": "go test -coverprofile=coverage.out ./...",
      "test_files_count": 1
    }
  },
  "packages_without_tests": []
}
EOF

cat >"$WORK/notes.json" <<'EOF'
{
  "agents_md_analyst_sections": "### Bounded contexts\n\n- **Core** — shared domain primitives in `pkg/core`.\n\n### Conventions\n\n- Table-driven Go tests; early returns over nested else."
}
EOF

chmod +x "$SCAFFOLD"
out="$(bash "$SCAFFOLD" scaffold "$REPO" "$WORK/boundary_scan.json" "$REPO/AGENTS.md")"

if ! grep -q 'agents_md_produced=true' <<<"$out"; then
  echo "FAIL: scaffold did not emit agents_md_produced=true" >&2
  echo "$out" >&2
  exit 1
fi

if [ ! -f "$REPO/AGENTS.md" ]; then
  echo "FAIL: AGENTS.md not written" >&2
  exit 1
fi

for needle in \
  '# AGENTS.md' \
  'agents.md' \
  'Setup commands' \
  'Testing instructions' \
  'go test ./...' \
  'go mod download' \
  'EditorConfig' \
  'Domain analysis (analyst)' \
  'Bounded contexts' \
  'Monorepo / split context' \
  'service-catalog.yaml'; do
  if ! grep -qF "$needle" "$REPO/AGENTS.md"; then
    echo "FAIL: AGENTS.md missing expected section: ${needle}" >&2
    cat "$REPO/AGENTS.md" >&2
    exit 1
  fi
done

if bash "$SCAFFOLD" scaffold "$REPO" "$WORK/missing.json" "$REPO/AGENTS.md" 2>/dev/null; then
  echo "FAIL: expected failure when boundary_scan.json is missing" >&2
  exit 1
fi

echo "OK: agents-md-scaffold tests passed"
