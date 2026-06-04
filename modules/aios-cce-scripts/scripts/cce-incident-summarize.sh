#!/usr/bin/env bash
# Compact incident-scoping summary from CCE JSON (avoid pasting full entitlements[] to LLM).
# Usage: cce-incident-summarize.sh CCE_JSON OUT_SUMMARY_JSON [ALERT_RESOURCE] [ALERT_OPERATION]
set -euo pipefail

CCE_JSON="${1:?CCE_JSON}"
OUT="${2:?OUT_SUMMARY_JSON}"
ALERT_RESOURCE="${3:-}"
ALERT_OPERATION="${4:-}"
CCE_INCIDENT_TOP_MODULES="${CCE_INCIDENT_TOP_MODULES:-8}"
CCE_INCIDENT_SAMPLE_LINES="${CCE_INCIDENT_SAMPLE_LINES:-12}"

jq \
  --arg res "$ALERT_RESOURCE" \
  --arg op "$ALERT_OPERATION" \
  --argjson top_mod "$CCE_INCIDENT_TOP_MODULES" \
  --argjson sample_n "$CCE_INCIDENT_SAMPLE_LINES" '
  (.entitlements // []) as $all |
  (if ($res != "" or $op != "") then
    $all | map(select(
      ($res == "" or ((.resource // "") | test($res; "i"))) and
      ($op == "" or ((.operation // "") | test($op; "i")))
    ))
  else $all end) as $scoped |
  ($scoped | group_by((.file // "") | split("/")[0]) | map({
    module: (.[0].file | split("/")[0]),
    count: length
  }) | sort_by(-.count) | .[0:$top_mod]) as $mods |
  {
    cce_scope_status: (if ($scoped | length) > 0 then "ok" else "empty" end),
    scoped_entitlement_count: ($scoped | length),
    scoped_modules: [$mods[].module],
    by_provider: (
      $scoped | group_by(.provider // "unknown") | map({key: (.[0].provider // "unknown"), value: length}) | from_entries
    ),
    sample_citations: ($scoped[0:$sample_n] | map({provider, resource, operation, file, line}))
  }
' "$CCE_JSON" >"$OUT"

echo "cce_scope_summary_path=$OUT"
