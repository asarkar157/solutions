#!/usr/bin/env bash
# seed-memory.sh — import curated episodic lessons into agent:memory-tutor via chat.
#
# Guild has no public REST API for memory_store; this script uses the memory-tutor
# agent chat API to call memory_store with type=episodic metadata.
#
# Prerequisites:
#   - GUILD_URL, STACKGEN_TOKEN, GUILD_PROJECT_ID (org scope)
#   - Scenario applied (memory-tutor agent exists)
#   - jq, curl
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_NAME="${SEED_AGENT:-memory-tutor}"
NAMESPACE="${SEED_NAMESPACE:-agent:memory-tutor}"
DATASET="${SEED_DATASET:-${SCRIPT_DIR}/data/lessons.jsonl}"
DRY_RUN=0
SLEEP_SECS=2
LIMIT=0

usage() {
  cat <<'EOF'
Usage:
  seed-memory.sh [options]

Options:
  --dataset PATH   JSONL lessons file (default: scripts/data/lessons.jsonl)
  --dry-run        Print actions without calling Guild
  --sleep N        Seconds between agent chat calls (default 2)
  --limit N        Process first N rows only

Environment:
  GUILD_URL          Guild base URL (required)
  STACKGEN_TOKEN     Bearer token (required)
  GUILD_PROJECT_ID   Org / project UUID (required)
  SEED_AGENT         Agent name (default memory-tutor)
  SEED_NAMESPACE     Memory namespace (default agent:memory-tutor)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dataset) DATASET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --sleep) SLEEP_SECS="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$DATASET" ]]; then
  echo "dataset not found: $DATASET" >&2
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
PRINCIPAL_HEADER="X-Stackgen-Principal: episodic-memory-demo-seed"

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
  local id fingerprint service namespace lesson full approved_by source
  id="$(jq -r '.id' <<<"$row")"
  fingerprint="$(jq -r '.fingerprint' <<<"$row")"
  service="$(jq -r '.service // ""' <<<"$row")"
  namespace="$(jq -r '.namespace // ""' <<<"$row")"
  lesson="$(jq -r '.lesson' <<<"$row")"
  full="$(jq -r '.full' <<<"$row")"
  approved_by="$(jq -r '.approved_by // "unknown"' <<<"$row")"
  source="$(jq -r '.source // "curated_import"' <<<"$row")"

  read -r -d '' message <<EOF || true
Bootstrap task ONLY — do not investigate external systems.

Call memory_store exactly once with:
- namespace: ${NAMESPACE}
- text: episodic lesson document for lesson_id=${id}, fingerprint=${fingerprint}, service=${service}, namespace=${namespace}, summary, root cause, and mitigation.

Include in the stored document body:
  type=episodic
  fingerprint=${fingerprint}
  service=${service}
  namespace=${namespace}
  source=${source}
  approved_by=${approved_by}
  lesson_id=${id}

Summary: ${lesson}

Full lesson:
${full}

After memory_store succeeds, reply with a single line: SEED_OK lesson_id=${id}
EOF

  local payload
  payload="$(jq -n \
    --arg msg "$message" \
    --arg app "episodic-memory-demo" \
    --arg eid "$id" \
    '{message: $msg, source_app: $app, source_metadata: {seed: "true", lesson_id: $eid, "guild.hidden": "true"}}')"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] would seed lesson ${id}"
    return 0
  fi

  echo "Seeding lesson ${id} via ${AGENT_NAME}..."
  local resp
  resp="$(guild_post_json "/api/v1/agents/${AGENT_NAME}/chat/start" "$payload")"
  local session_id trace_id
  session_id="$(jq -r '.session_id // empty' <<<"$resp")"
  trace_id="$(jq -r '.trace_id // empty' <<<"$resp")"
  echo "  session_id=${session_id} trace_id=${trace_id}"
  sleep "$SLEEP_SECS"
}

line_count=0
processed=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "${line// }" ]] && continue
  line_count=$((line_count + 1))
  if [[ "$LIMIT" -gt 0 && "$line_count" -gt "$LIMIT" ]]; then
    break
  fi
  store_via_agent "$line"
  processed=$((processed + 1))
done <"$DATASET"

echo "Done. Processed ${processed} lessons into namespace ${NAMESPACE}."
echo "Verify in Guild Memory Explorer: filter namespace ${NAMESPACE}, type episodic."
