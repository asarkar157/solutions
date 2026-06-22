#!/usr/bin/env bash
# Seed curated aiden-demo past incidents into Guild shared:incidents memory.
#
# Prerequisites:
#   - GUILD_URL, STACKGEN_TOKEN, GUILD_PROJECT_ID exported (or in sks.auto.tfvars)
#   - sg_knowledge_namespace shared:incidents provisioned; investigator has admin access
#   - jq, curl
#
# Usage:
#   ./scripts/seed-past-incidents.sh              # dry-run first row, then full bootstrap
#   ./scripts/seed-past-incidents.sh --dry-run  # print actions only
#   ./scripts/seed-past-incidents.sh --limit 2  # bootstrap first N rows only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATASET="${DATASET:-${SCRIPT_DIR}/data/aiden-demo-incidents.jsonl}"
BOOTSTRAP="${SCENARIO_DIR}/../incident-triage/scripts/bootstrap-memory.sh"
TFVARS="${SCENARIO_DIR}/sks.auto.tfvars"
DRY_RUN_ONLY=0
LIMIT=0
SKIP_DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: seed-past-incidents.sh [options]

Options:
  --dry-run     Dry-run bootstrap only (no Guild calls)
  --limit N     Bootstrap first N JSONL rows only
  --skip-dry    Skip the initial --limit 1 dry-run
  --dataset PATH  Override JSONL path

Environment (or values parsed from sks.auto.tfvars when present):
  GUILD_URL, STACKGEN_TOKEN, GUILD_PROJECT_ID
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN_ONLY=1; shift ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --skip-dry) SKIP_DRY_RUN=1; shift ;;
    --dataset) DATASET="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$DATASET" ]]; then
  echo "error: dataset not found: $DATASET" >&2
  exit 1
fi
if [[ ! -x "$BOOTSTRAP" ]]; then
  echo "error: bootstrap script not found or not executable: $BOOTSTRAP" >&2
  exit 1
fi

load_tfvar() {
  local key="$1"
  if [[ -f "$TFVARS" ]]; then
    grep -E "^[[:space:]]*${key}[[:space:]]*=" "$TFVARS" 2>/dev/null \
      | head -1 \
      | sed -E 's/^[^=]+=[[:space:]]*"([^"]*)".*/\1/' || true
  fi
}

if [[ -z "${GUILD_URL:-}" ]]; then
  base="$(load_tfvar stackgen_url)"
  if [[ -n "$base" ]]; then
    GUILD_URL="${base%/}/guild"
    export GUILD_URL
  fi
fi
if [[ -z "${STACKGEN_TOKEN:-}" ]]; then
  STACKGEN_TOKEN="$(load_tfvar stackgen_token)"
  export STACKGEN_TOKEN
fi
if [[ -z "${GUILD_PROJECT_ID:-}" ]]; then
  GUILD_PROJECT_ID="$(load_tfvar stackgen_project_id)"
  export GUILD_PROJECT_ID
fi

for var in GUILD_URL STACKGEN_TOKEN GUILD_PROJECT_ID; do
  if [[ -z "${!var:-}" ]]; then
    echo "error: $var is required (export or set in ${TFVARS})" >&2
    exit 1
  fi
done

row_count="$(grep -c '^{' "$DATASET" || true)"
echo "Dataset: ${DATASET} (${row_count} rows)"
echo "Guild:   ${GUILD_URL} org=${GUILD_PROJECT_ID}"

bootstrap_args=(--dataset "$DATASET" --sleep 3)

if [[ "$DRY_RUN_ONLY" -eq 1 ]]; then
  echo "==> dry-run bootstrap"
  "$BOOTSTRAP" "${bootstrap_args[@]}" --dry-run --limit 1
  exit 0
fi

if [[ "$SKIP_DRY_RUN" -eq 0 ]]; then
  echo "==> dry-run smoke (1 row)"
  "$BOOTSTRAP" "${bootstrap_args[@]}" --dry-run --limit 1
fi

if [[ "$LIMIT" -gt 0 ]]; then
  echo "==> bootstrap --limit ${LIMIT}"
  "$BOOTSTRAP" "${bootstrap_args[@]}" --limit "$LIMIT"
else
  echo "==> bootstrap all rows"
  "$BOOTSTRAP" "${bootstrap_args[@]}"
fi

cat <<EOF

Done. Verify in Guild Memory Explorer:
  namespace: shared:incidents
  search:    incident_id=AIDEN-001

Re-run an investigation on order-service env:demo and check prior_incidents in the execution trace.
EOF
