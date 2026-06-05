#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat >"${WORK}/scan.json" <<'EOF'
{
  "modules": [
    {"path": "a", "depends_on": []},
    {"path": "b", "depends_on": ["a"]},
    {"path": "c", "depends_on": ["a", "b"]}
  ]
}
EOF

bash "${ROOT}/scripts/build-coupling-matrix.sh" build "${WORK}/scan.json" "${WORK}/matrix.json"

inbound_b="$(jq -r '.modules[] | select(.path=="b") | .inbound_edges' "${WORK}/matrix.json")"
outbound_c="$(jq -r '.modules[] | select(.path=="c") | .outbound_edges' "${WORK}/matrix.json")"
hub="$(jq -r '.hub_module' "${WORK}/matrix.json")"

[ "$inbound_b" = "1" ] || { echo "FAIL: b inbound_edges=$inbound_b"; exit 1; }
[ "$outbound_c" = "2" ] || { echo "FAIL: c outbound_edges=$outbound_c"; exit 1; }
[ "$hub" = "a" ] || { echo "FAIL: hub=$hub"; exit 1; }

cat >"${WORK}/scan-test-hub.json" <<'EOF'
{
  "modules": [
    {"path": "resilience4j-core", "depends_on": []},
    {"path": "resilience4j-test", "depends_on": ["resilience4j-core"]},
    {"path": "resilience4j-circuitbreaker", "depends_on": ["resilience4j-core", "resilience4j-test"]}
  ]
}
EOF

bash "${ROOT}/scripts/build-coupling-matrix.sh" build "${WORK}/scan-test-hub.json" "${WORK}/matrix-test-hub.json"
hub_test="$(jq -r '.hub_module' "${WORK}/matrix-test-hub.json")"
[ "$hub_test" = "resilience4j-core" ] || {
  echo "FAIL: expected hub resilience4j-core excluding test module, got ${hub_test}"
  exit 1
}

echo "OK: coupling matrix test passed"
