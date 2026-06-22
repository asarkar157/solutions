#!/usr/bin/env bash
# build-prompt-from-row.sh — emit initial_prompt aligned with stackgen-sre-app buildInvestigationPrompt.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  build-prompt-from-row.sh --row '<json object>'
  build-prompt-from-row.sh --row-file path.json [--prompt-only]

Reads incident fields (labels, description, severity, etc.) and prints initial_prompt to stdout.
With --prompt-only, prints only the prompt (for inspection). Otherwise prints full JSON row with initial_prompt set.
EOF
}

ROW=""
ROW_FILE=""
PROMPT_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --row) ROW="$2"; shift 2 ;;
    --row-file) ROW_FILE="$2"; shift 2 ;;
    --prompt-only) PROMPT_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -n "$ROW_FILE" ]]; then
  ROW="$(cat "$ROW_FILE")"
fi
if [[ -z "$ROW" ]]; then
  echo "missing --row or --row-file" >&2
  usage
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

PROMPT="$(jq -r '
  def inv_id:
    if .evaluation_id // "" | length > 0 then
      "00000000-0000-4000-8000-" + (.id | gsub("[^0-9]"; "") | .[0:12] | . + ("0" * (12 - length)) | .[0:12])
    else
      "00000000-0000-4000-8000-000000000099"
    end;
  def fingerprint:
    if .labels.alertname // "" | length > 0 then
      (.id | ascii_downcase | gsub("[^a-z0-9]"; "-"))
    else
      (.id | ascii_downcase | gsub("[^a-z0-9]"; "-"))
    end;
  "Investigate the alert below.\n\nInvestigation ID: " + inv_id + "\n" +
  "Alert instance fingerprint: " + fingerprint + "\n" +
  (if .labels.alertname // "" | length > 0 then "Alert:     " + .labels.alertname + "\n" else "" end) +
  (if .severity // "" | length > 0 then "Severity:  " + .severity + "\n" else "Severity:  warning\n" end) +
  (if .source // "" | length > 0 then "Source:    " + .source + "\n" else "Source:    grafana-demo\n" end) +
  (if .triggered_at // "" | length > 0 then "Triggered: " + .triggered_at + "\n" else "" end) +
  (if .description // "" | length > 0 then "Description: " + .description + "\n" else "" end) +
  (if .alert_role // "" | length > 0 then "Pre-classified at ingest — alert_role: " + .alert_role + "\n" else "" end) +
  (if .likely_upstream // "" | length > 0 then "Likely upstream (ingest hint): " + .likely_upstream + "\n" else "" end) +
  (if (.labels // {}) | length > 0 then
    "\nTarget instance labels (pass as label_filters to scope_alert or list_firing_instances;\n" +
    "also pass instance_fingerprint above as instance_fingerprint):\n" +
    ([.labels | to_entries[] | "  " + .key + "=" + .value] | join("\n")) + "\n" +
    "label_filters JSON: " + (.labels | tojson) + "\n\n"
  else "\n" end)
' <<<"$ROW")"

if [[ "$PROMPT_ONLY" -eq 1 ]]; then
  printf '%s' "$PROMPT"
  exit 0
fi

if jq -e '.initial_prompt // "" | length > 0' <<<"$ROW" >/dev/null 2>&1; then
  echo "$ROW" | jq .
  exit 0
fi

jq --arg prompt "$PROMPT" '.initial_prompt = $prompt' <<<"$ROW"
