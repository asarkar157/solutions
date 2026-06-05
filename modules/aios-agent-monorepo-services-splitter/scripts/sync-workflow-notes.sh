#!/usr/bin/env bash
# Merge workflow_notes_snapshot and optional overlays into WORK_ROOT/notes.json for script materialization.
set -euo pipefail

merge_json_into_notes() {
  local work_root="${1:?WORK_ROOT}"
  local overlay_path="${2:?OVERLAY}"
  local notes="${work_root}/notes.json"
  [ -f "$notes" ] || echo '{}' >"$notes"
  [ -f "$overlay_path" ] || return 0
  local tmp
  tmp="$(mktemp)"
  jq -s '
    .[0] as $base |
    .[1] as $over |
    if ($over | type) == "string" then
      ($base * (($over | fromjson?) // {}))
    else
      ($base * $over)
    end
  ' "$notes" "$overlay_path" >"$tmp" && mv "$tmp" "$notes"
}

cmd_sync() {
  local work_root="${1:?WORK_ROOT}"
  local notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"

  local snap_raw
  snap_raw="$(jq -r '.workflow_notes_snapshot // empty' "$notes" 2>/dev/null || true)"
  if [ -n "$snap_raw" ] && [ "$snap_raw" != "null" ]; then
    local snap_file="${work_root}/.workflow_notes_snapshot.json"
    if printf '%s' "$snap_raw" | jq -e 'type == "object"' >/dev/null 2>&1; then
      printf '%s' "$snap_raw" | jq -c '.' >"$snap_file"
    elif printf '%s' "$snap_raw" | jq -e . >/dev/null 2>&1; then
      printf '%s' "$snap_raw" | jq -c '.' >"$snap_file"
    fi
    if [ -f "$snap_file" ]; then
      merge_json_into_notes "$work_root" "$snap_file"
    fi
  fi

  if [ -f "${work_root}/guild-notes-overlay.json" ]; then
    merge_json_into_notes "$work_root" "${work_root}/guild-notes-overlay.json"
  fi

  echo "workflow_notes_synced=true"
}

case "${1:-}" in
  sync) shift; cmd_sync "$@" ;;
  *)
    echo "usage: sync-workflow-notes.sh sync WORK_ROOT" >&2
    exit 1
    ;;
esac
