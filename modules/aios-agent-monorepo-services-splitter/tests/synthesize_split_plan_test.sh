#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp -R "${ROOT}/scripts" "${WORK}/scripts"
chmod +x "${WORK}/scripts/"*.sh

cat >"${WORK}/boundary_scan.json" <<'EOF'
{
  "repo_archetype": "library_monorepo",
  "languages": ["java"],
  "modules": [
    {"path": "resilience4j-core", "language": "java", "depends_on": []},
    {"path": "resilience4j-circuitbreaker", "language": "java", "depends_on": ["resilience4j-core"]},
    {"path": "resilience4j-spring", "language": "java", "depends_on": ["resilience4j-circuitbreaker", "resilience4j-core"]}
  ],
  "test_inventory": {
    "java": {"recommended_command": "./gradlew test", "confidence": 0.9}
  },
  "packages_without_tests": []
}
EOF

bash "${WORK}/scripts/build-coupling-matrix.sh" build "${WORK}/boundary_scan.json" "${WORK}/coupling-matrix.json"
MONOREPO_SPLIT_ALLOW_DIRECT=1 MAX_RECOMMENDED_SERVICES=5 \
  bash "${WORK}/scripts/synthesize-split-plan.sh" synthesize "$WORK"

test -f "${WORK}/docs/architecture/service-catalog.yaml"
test -f "${WORK}/docs/architecture/README.md"
test -f "${WORK}/docs/architecture/for-developers.md"
grep -q 'resilience4j-core' "${WORK}/docs/architecture/service-catalog.yaml"
grep -q 'example-service' "${WORK}/docs/architecture/service-catalog.yaml" && {
  echo "FAIL: catalog must not contain example-service placeholder" >&2
  exit 1
}

hub="$(jq -r '.hub_module' "${WORK}/coupling-matrix.json")"
if [ "$hub" != "resilience4j-core" ]; then
  echo "FAIL: expected hub resilience4j-core got ${hub}" >&2
  exit 1
fi

echo "OK: synthesize-split-plan golden test passed"
