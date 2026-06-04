#!/usr/bin/env bash
# compliance-aggregate.sh — merge per-repo CCE JSON into one compliance-evidence digest.
# Usage: compliance-aggregate.sh WORK_ROOT [OUT_JSON]
set -euo pipefail

WORK_ROOT="${1:?work root}"
OUT="${2:-${WORK_ROOT}/compliance-evidence.json}"

total=0
repos_scanned=0
touchpoints=0

while IFS= read -r -d '' f; do
  repos_scanned=$((repos_scanned + 1))
  cnt="$(jq -r '.summary.total_entitlements // (.entitlements | length) // 0' "$f" 2>/dev/null || echo 0)"
  total=$((total + cnt))
  tp="$(jq '[.entitlements[]? | select(.provider == "REGULATORY" or (.resource | test("pci|hipaa|soc"; "i")))] | length' "$f" 2>/dev/null || echo 0)"
  touchpoints=$((touchpoints + tp))
done < <(find "$WORK_ROOT" -name 'cce-*.json' -type f -print0 2>/dev/null || true)

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson repos_scanned "$repos_scanned" \
  --argjson total_call_sites "$total" \
  --argjson regulatory_touchpoints "$touchpoints" \
  '{
    generated_at: $generated_at,
    repos_scanned: $repos_scanned,
    total_call_sites: $total_call_sites,
    regulatory_touchpoint_count: $regulatory_touchpoints
  }' >"$OUT"

echo "compliance_evidence_path=$OUT"
echo "total_call_sites=$total"
echo "regulatory_touchpoint_count=$touchpoints"
