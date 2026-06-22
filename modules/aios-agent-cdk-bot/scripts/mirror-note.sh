#!/usr/bin/env bash
# Append a single string key to $WORK_ROOT/notes.json (orchestration §3b).
# Usage: mirror-note.sh WORK_ROOT KEY VALUE
set -euo pipefail

WORK_ROOT="${1:?WORK_ROOT}"
KEY="${2:?KEY}"
VALUE="${3:?VALUE}"
NOTES="$WORK_ROOT/notes.json"

mkdir -p "$WORK_ROOT"
[ -f "$NOTES" ] || echo '{}' >"$NOTES"

jq --arg k "$KEY" --arg v "$VALUE" '. + {($k): $v}' "$NOTES" >"$NOTES.tmp" \
  && mv "$NOTES.tmp" "$NOTES"
echo "mirrored:$KEY"
