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

echo "OK: coupling matrix test passed"
