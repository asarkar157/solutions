#!/usr/bin/env bash
# Unit tests for scaffold-services.sh catalog parsing and layout validation.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAFFOLD="${ROOT}/scripts/scaffold-services.sh"
WORK="$(mktemp -d)"
REPO="${WORK}/repo"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$REPO/docs/architecture" "$WORK"

cat >"$WORK/inline-catalog.yaml" <<'EOF'
version: "1.0"
language: java
build_tool: gradle
services:
  - {name: resilience-core-svc, repo_path: services/resilience-core/, bounded_context: shared-kernel}
  - {name: retry-svc, repo_path: services/retry/, bounded_context: fault-tolerance-patterns}
EOF

cat >"$WORK/block-catalog.yaml" <<'EOF'
services:
  - name: billing-svc
    path: services/billing
    rationale: Billing bounded context
  - name: orders-svc
    repo_path: services/orders/
EOF

inline="$(bash "$SCAFFOLD" list-entries "$WORK/inline-catalog.yaml" | sort)"
expect_inline=$'resilience-core\tresilience-core-svc\nretry\tretry-svc'
if [ "$inline" != "$expect_inline" ]; then
  echo "FAIL: inline catalog parse" >&2
  echo "got: $inline" >&2
  exit 1
fi

block="$(bash "$SCAFFOLD" list-entries "$WORK/block-catalog.yaml" | sort)"
expect_block=$'billing\tbilling-svc\norders\torders-svc'
if [ "$block" != "$expect_block" ]; then
  echo "FAIL: block catalog parse" >&2
  echo "got: $block" >&2
  exit 1
fi

touch "$REPO/settings.gradle.kts"
MONOREPO_SPLIT_ALLOW_DIRECT=1 SCRIPT_PACK_VERSION=20260602.4 \
  bash "$SCAFFOLD" scaffold "$WORK" "$REPO" "$WORK/inline-catalog.yaml"

for svc in resilience-core retry; do
  if [ ! -f "$REPO/services/$svc/README.md" ]; then
    echo "FAIL: missing README for $svc" >&2
    exit 1
  fi
  if [ "$(wc -c <"$REPO/services/$svc/README.md" | tr -d ' ')" -lt 120 ]; then
    echo "FAIL: README too short for $svc" >&2
    exit 1
  fi
  if [ ! -f "$REPO/services/$svc/src/test/java/com/guild/${svc//-/_}/ScaffoldTest.java" ]; then
    echo "FAIL: missing JUnit stub for $svc" >&2
    exit 1
  fi
  if [ ! -f "$REPO/services/$svc/build.gradle.kts" ]; then
    echo "FAIL: missing build.gradle.kts for $svc" >&2
    exit 1
  fi
done

if ! grep -q 'include(":services:resilience-core")' "$REPO/settings.gradle.kts"; then
  echo "FAIL: settings.gradle.kts missing guild scaffold includes" >&2
  cat "$REPO/settings.gradle.kts" >&2
  exit 1
fi
if grep -qE '^[[:space:]]*# BEGIN guild-split-scaffold-includes' "$REPO/settings.gradle.kts"; then
  echo "FAIL: settings.gradle.kts must use // markers, not shell # comments" >&2
  cat "$REPO/settings.gradle.kts" >&2
  exit 1
fi

if [ "$(jq -r '.scaffold_layout_validated' "$WORK/notes.json")" != "true" ]; then
  echo "FAIL: scaffold_layout_validated not true in notes" >&2
  cat "$WORK/notes.json" >&2
  exit 1
fi

echo "OK: scaffold-services tests passed"
