#!/usr/bin/env bash
# bootstrap-memory.sh — import curated golden RCAs into Guild shared incident memory.
#
# Guild has no public REST API for memory_store; this script uses the investigator
# agent chat API to call memory_store into namespace shared:incidents (curated import).
#
# Prerequisites:
#   - GUILD_URL, STACKGEN_TOKEN, GUILD_PROJECT_ID (org scope)
#   - sg_knowledge_namespace shared:incidents provisioned; investigator has admin access
#   - jq, curl
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_NAME="${BOOTSTRAP_AGENT:-stackgen-sre-investigator}"
NAMESPACE="${BOOTSTRAP_NAMESPACE:-shared:incidents}"
MODE="agent"
DATASET=""
DRY_RUN=0
SLEEP_SECS=2
LIMIT=0

usage() {
  cat <<'EOF'
Usage:
  bootstrap-memory.sh --dataset incidents.jsonl [options]

Options:
  --mode agent|knowledge   agent = memory_store via investigator chat (default)
                           knowledge = upload golden_rca_full as KB documents (pull path)
  --dry-run                Print actions without calling Guild
  --sleep N                Seconds between agent chat calls (default 2)
  --limit N                Process first N rows only

Environment:
  GUILD_URL          Guild base URL (required)
  STACKGEN_TOKEN     Bearer token (required)
  GUILD_PROJECT_ID   Org / project UUID (required)
  BOOTSTRAP_AGENT    Agent name (default stackgen-sre-investigator)
  BOOTSTRAP_NAMESPACE Memory namespace (default shared:incidents)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dataset) DATASET="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --sleep) SLEEP_SECS="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$DATASET" || ! -f "$DATASET" ]]; then
  echo "missing or invalid --dataset" >&2
  usage
  exit 1
fi

for var in GUILD_URL STACKGEN_TOKEN GUILD_PROJECT_ID; do
  if [[ -z "${!var:-}" ]]; then
    echo "$var is required" >&2
    exit 1
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

GUILD_URL="${GUILD_URL%/}"
AUTH_HEADER="Authorization: Bearer ${STACKGEN_TOKEN}"
PRINCIPAL_HEADER="X-Stackgen-Principal: incident-triage-poc-bootstrap"

# Hosted StackGen tenants expose Guild REST under /guild.
if [[ -z "${GUILD_API_PREFIX:-}" ]]; then
  if [[ "$GUILD_URL" != */guild ]]; then
    probe_code="$(curl -sS -o /dev/null -w "%{http_code}" \
      "${GUILD_URL}/guild/api/v1/workflows?orgId=${GUILD_PROJECT_ID}&limit=1" \
      -H "$AUTH_HEADER" -H "$PRINCIPAL_HEADER" 2>/dev/null || echo 000)"
    if [[ "$probe_code" == "200" ]]; then
      GUILD_URL="${GUILD_URL}/guild"
    fi
  fi
elif [[ "$GUILD_API_PREFIX" != "/" ]]; then
  GUILD_URL="${GUILD_URL}${GUILD_API_PREFIX}"
fi

# Guild scopes org-owned workflows via orgId query param (not X-Guild-Project-Id alone).
guild_api_path() {
  local path="$1"
  local sep="?"
  if [[ "$path" == *"?"* ]]; then
    sep="&"
  fi
  printf '%s%sorgId=%s' "$path" "$sep" "$GUILD_PROJECT_ID"
}

guild_post_json() {
  local path="$1"
  local body="$2"
  curl -sfS -X POST "${GUILD_URL}$(guild_api_path "$path")" \
    -H "$AUTH_HEADER" \
    -H "$PRINCIPAL_HEADER" \
    -H "Content-Type: application/json" \
    -d "$body"
}

store_via_agent() {
  local row="$1"
  local id root summary full approved_by source service namespace
  id="$(jq -r '.id' <<<"$row")"
  root="$(jq -r '.golden_root_cause' <<<"$row")"
  full="$(jq -r '.golden_rca_full' <<<"$row")"
  approved_by="$(jq -r '.approved_by // "unknown"' <<<"$row")"
  source="$(jq -r '.source // "curated_import"' <<<"$row")"
  service="$(jq -r '.labels.service // ""' <<<"$row")"
  namespace="$(jq -r '.labels.namespace // ""' <<<"$row")"

  summary="PoC curated incident ${id}: ${root}"

  read -r -d '' message <<EOF || true
Bootstrap task ONLY — do not investigate, do not call Grafana tools.

Call memory_store exactly once with:
- namespace: ${NAMESPACE}
- text: a concise memory document containing incident_id=${id}, service=${service}, namespace=${namespace}, root_cause, summary, and key mitigation steps from the published RCA below.

Metadata to include in the stored document (plain text body):
  source=${source}
  approved_by=${approved_by}
  type=curated_import
  incident_id=${id}

Published RCA:
${full}

After memory_store succeeds, reply with a single line: BOOTSTRAP_OK incident_id=${id}
EOF

  local payload
  payload="$(jq -n \
    --arg msg "$message" \
    --arg app "incident-triage-poc" \
    --arg eid "$id" \
    '{message: $msg, source_app: $app, source_metadata: {bootstrap: "true", evaluation_id: $eid, "guild.hidden": "true"}}')"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would bootstrap memory for ${id}"
    return 0
  fi

  echo "Bootstrapping memory for ${id} via ${AGENT_NAME}..."
  local resp
  resp="$(guild_post_json "/api/v1/agents/${AGENT_NAME}/chat/start" "$payload")"
  local session_id trace_id
  session_id="$(jq -r '.session_id // empty' <<<"$resp")"
  trace_id="$(jq -r '.trace_id // empty' <<<"$resp")"
  echo "  session_id=${session_id} trace_id=${trace_id}"
  sleep "$SLEEP_SECS"
}

upload_knowledge_doc() {
  local row="$1"
  local id title
  id="$(jq -r '.id' <<<"$row")"
  title="PoC Incident ${id}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would upload knowledge doc for ${id}"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  jq -r '.golden_rca_full' <<<"$row" >"$tmp"

  echo "Uploading knowledge document for ${id}..."
  curl -sfS -X POST "${GUILD_URL}$(guild_api_path "/api/v1/knowledge/documents/upload")" \
    -H "$AUTH_HEADER" \
    -H "$PRINCIPAL_HEADER" \
    -F "title=${title}" \
    -F "file=@${tmp};type=text/markdown" \
    >/dev/null || echo "  warning: knowledge upload failed for ${id} (check KB permissions)" >&2

  rm -f "$tmp"
}

line_count=0
processed=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "${line// }" ]] && continue
  line_count=$((line_count + 1))
  if [[ "$LIMIT" -gt 0 && "$line_count" -gt "$LIMIT" ]]; then
    break
  fi
  if [[ "$MODE" == "knowledge" ]]; then
    upload_knowledge_doc "$line"
  else
    store_via_agent "$line"
  fi
  processed=$((processed + 1))
done <"$DATASET"

echo "Done. Processed ${processed} rows (mode=${MODE})."
echo "Verify in Guild Memory Explorer: filter namespace ${NAMESPACE}, search incident_id."
