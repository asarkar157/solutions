#!/usr/bin/env bash
# db-state-splitter stage runner — invoke ONLY via _embed_dbsplit_run (DBSPLIT_EMBEDDED=1).
# Direct `bash $WORK_ROOT/scripts/stage-runner.sh` is rejected (agent script drift).
# Usage: DBSPLIT_EMBEDDED=1 bash -s <command> [args...] << 'DBSPLIT_STAGE_RUNNER' ... DBSPLIT_STAGE_RUNNER
set -euo pipefail

SCRIPT_PACK_VERSION="20260531.9"
DBSPLIT_DEFAULT_STRATEGY="${DBSPLIT_DEFAULT_STRATEGY:-tag_seeded_connectivity}"
DBSPLIT_DEFAULT_CAP="${DBSPLIT_DEFAULT_CAP:-0}"
REQUIRED_ALLOCATE_MARKER="def merge_small_by_seed"

mirror_note() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  local value="${3:?VALUE}"
  local notes="${work_root}/notes.json"
  mkdir -p "$work_root"
  [ -f "$notes" ] || echo '{}' >"$notes"
  jq --arg k "$key" --arg v "$value" '. + {($k): $v}' "$notes" >"${notes}.tmp" \
    && mv "${notes}.tmp" "$notes"
  echo "mirrored:${key}=${value}"
}

read_note() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  local notes="${work_root}/notes.json"
  [ -f "$notes" ] || return 1
  jq -r --arg k "$key" '.[$k] // empty' "$notes"
}

note_or_default() {
  local work_root="${1:?WORK_ROOT}"
  local key="${2:?KEY}"
  local default="${3:?DEFAULT}"
  local val
  val="$(read_note "$work_root" "$key" 2>/dev/null || true)"
  if [ -n "$val" ]; then
    printf '%s' "$val"
    return 0
  fi
  printf '%s' "$default"
}

_runner_dir() {
  cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || printf '%s' "."
}

sha256_file() {
  sha256sum "$1" 2>/dev/null | awk '{print $1}'
}

require_embedded_invocation() {
  if [ "${DBSPLIT_EMBEDDED:-}" = "1" ]; then
    return 0
  fi
  if [ "${DBSPLIT_ALLOW_DIRECT:-}" = "1" ]; then
    return 0
  fi
  local sibling="${1:-$(_runner_dir)/allocate_manifest.py}"
  if [ -f "$sibling" ] && grep -q "$REQUIRED_ALLOCATE_MARKER" "$sibling" 2>/dev/null; then
    return 0
  fi
  echo "script_pack_error=invoke_via_embed_dbsplit_run_set_DBSPLIT_EMBEDDED=1" >&2
  return 1
}

verify_allocate_manifest_py() {
  local py_path="${1:?PY}"
  if [ ! -f "$py_path" ]; then
    echo "script_pack_error=missing_allocate_manifest path=${py_path}" >&2
    return 1
  fi
  if ! grep -q "$REQUIRED_ALLOCATE_MARKER" "$py_path" 2>/dev/null; then
    echo "script_pack_error=stale_allocate_manifest_missing_merge_small_by_seed" >&2
    return 1
  fi
  if [ -n "${DBSPLIT_ALLOCATE_SHA256:-}" ]; then
    local actual expected="${DBSPLIT_ALLOCATE_SHA256}"
    actual="$(sha256_file "$py_path")"
    if [ "$actual" != "$expected" ]; then
      echo "script_pack_error=allocate_sha256_mismatch expected=${expected} actual=${actual}" >&2
      return 1
    fi
  fi
  return 0
}

write_script_pack_stamp() {
  local work_root="${1:?WORK_ROOT}"
  local py_path="${work_root}/scripts/allocate_manifest.py"
  mkdir -p "${work_root}/scripts"
  printf '%s\n' "$SCRIPT_PACK_VERSION" >"${work_root}/scripts/.script_pack_version"
  if [ -f "$py_path" ]; then
    sha256_file "$py_path" >"${work_root}/scripts/.allocate_sha256"
  fi
  mirror_note "$work_root" "script_pack_version" "$SCRIPT_PACK_VERSION"
}

resolve_allocate_py() {
  local work_root="${1:?WORK_ROOT}"
  local dest="${work_root}/scripts/allocate_manifest.py"
  mkdir -p "$(dirname "$dest")"

  if [ -f "$dest" ] && verify_allocate_manifest_py "$dest"; then
    write_script_pack_stamp "$work_root" >/dev/null
    printf '%s' "$dest"
    return 0
  fi

  local sibling
  sibling="$(_runner_dir)/allocate_manifest.py"
  if [ -f "$sibling" ] && grep -q "$REQUIRED_ALLOCATE_MARKER" "$sibling" 2>/dev/null; then
    cp "$sibling" "$dest"
    verify_allocate_manifest_py "$dest"
    write_script_pack_stamp "$work_root" >/dev/null
    printf '%s' "$dest"
    return 0
  fi

  echo "allocate_manifest_error=missing_or_unverified_allocate_manifest.py" >&2
  return 1
}

run_py() {
  local work_root="${1:?WORK_ROOT}"
  shift
  local py
  py="$(resolve_allocate_py "$work_root")"
  python3 "$py" "$@"
}

managed_instance_count() {
  local state_path="${1:?STATE}"
  jq '[.resources[]? | select(.mode=="managed") | .instances[]?] | length' "$state_path" 2>/dev/null \
    || jq '[.resources[]? | select(.mode=="managed")] | length' "$state_path"
}

cmd_preflight() {
  local work_root="${1:?WORK_ROOT}"
  require_embedded_invocation || return 1
  if ! command -v python3 >/dev/null 2>&1; then
    echo "preflight_error=python3_missing"
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "preflight_error=jq_missing"
    return 1
  fi
  mkdir -p "${work_root}/state" "${work_root}/scripts" "${work_root}/groups"
  chmod 700 "$work_root"
  touch "${work_root}/.write_test" && rm "${work_root}/.write_test"
  [ -f "${work_root}/notes.json" ] || echo '{}' >"${work_root}/notes.json"
  mirror_note "$work_root" "scratch_root" "$work_root"
  mirror_note "$work_root" "script_pack_version" "$SCRIPT_PACK_VERSION"
  echo "preflight_ok=true"
  echo "work_root_created=true"
  echo "script_pack_version=${SCRIPT_PACK_VERSION}"
}

resolve_state_uri() {
  local uri="${1:-}"
  if [ -z "$uri" ] && [ -n "${TFSTATE_FILE:-}" ]; then
    uri="$TFSTATE_FILE"
  fi
  if [ -z "$uri" ] && [ -n "${MONOLITH_STATE_URI:-}" ]; then
    uri="$MONOLITH_STATE_URI"
  fi
  printf '%s' "$uri"
}

download_google_drive() {
  local uri="$1"
  local dest="$2"
  local file_id=""
  file_id="$(printf '%s' "$uri" | sed -nE 's#.*/d/([a-zA-Z0-9_-]+)/?.*#\1#p' | head -1)"
  if [ -z "$file_id" ]; then
    file_id="$(printf '%s' "$uri" | sed -nE 's#.*[?&]id=([a-zA-Z0-9_-]+).*#\1#p' | head -1)"
  fi
  if [ -z "$file_id" ]; then
    echo "download_error=google_drive_file_id_not_found uri=${uri}" >&2
    return 1
  fi
  if command -v gdown >/dev/null 2>&1; then
    gdown --id "$file_id" -O "$dest" || gdown --fuzzy "$uri" -O "$dest"
    return 0
  fi
  curl -LfsS "https://drive.google.com/uc?export=download&id=${file_id}&confirm=t" -o "$dest"
}

cmd_download_state() {
  local work_root="${1:?WORK_ROOT}"
  local state_uri
  state_uri="$(resolve_state_uri "${2:-}")"
  local dest="${work_root}/state/terraform.tfstate"
  mkdir -p "$(dirname "$dest")"

  if [ -z "$state_uri" ]; then
    echo "download_error=missing_monolith_state_uri_or_tfstate_file"
    return 1
  fi

  mirror_note "$work_root" "monolith_state_uri" "$state_uri"

  if [[ "$state_uri" == file://* ]]; then
    cp "${state_uri#file://}" "$dest"
  elif [ -f "$state_uri" ]; then
    cp "$state_uri" "$dest"
  elif [[ "$state_uri" == *drive.google.com* ]]; then
    download_google_drive "$state_uri" "$dest"
  elif [[ "$state_uri" == s3://* ]]; then
    aws s3 cp "$state_uri" "$dest"
  elif [[ "$state_uri" == gs://* ]]; then
    gcloud storage cp "$state_uri" "$dest"
  else
    curl -LfsS "$state_uri" -o "$dest"
  fi

  if [ ! -s "$dest" ]; then
    echo "download_error=empty_state_file uri=${state_uri}"
    return 1
  fi
  if ! jq -e '.resources' "$dest" >/dev/null 2>&1; then
    echo "download_error=invalid_tfstate_json uri=${state_uri}"
    return 1
  fi

  local count
  count="$(managed_instance_count "$dest")"
  if [ "${count:-0}" -eq 0 ]; then
    echo "download_warning=zero_managed_resources uri=${state_uri}"
  fi
  mirror_note "$work_root" "monolith_state_local_path" "$dest"
  mirror_note "$work_root" "monolith_resource_count" "$count"

  local strategy cap
  strategy="$(read_note "$work_root" "grouping_strategy" || true)"
  cap="$(read_note "$work_root" "max_resources_per_appstack" || true)"

  if [ "$count" -gt 5000 ] && [ -z "$strategy" ]; then
    strategy="${DBSPLIT_DEFAULT_STRATEGY}"
    cap="${DBSPLIT_DEFAULT_CAP}"
    mirror_note "$work_root" "grouping_strategy" "$strategy"
    mirror_note "$work_root" "max_resources_per_appstack" "$cap"
    echo "auto_promoted_grouping=true strategy=${strategy} cap=${cap}"
  fi

  echo "monolith_state_local_path=${dest}"
  echo "monolith_resource_count=${count}"
}

cmd_discover_anchors() {
  local work_root="${1:?WORK_ROOT}"
  local state_path="${2:-${work_root}/state/terraform.tfstate}"

  if [ ! -f "$state_path" ]; then
    echo "discover_error=state_file_missing path=${state_path}"
    return 1
  fi

  run_py "$work_root" inventory "$state_path" "$work_root"

  local seed_count inv_count
  seed_count="$(read_note "$work_root" "anchor_seeds_extracted" || jq 'length' "${work_root}/logical_group_seeds.json")"
  inv_count="$(jq 'length' "${work_root}/db_anchor_inventory.json")"
  mirror_note "$work_root" "logical_group_seeds_path" "${work_root}/logical_group_seeds.json"
  mirror_note "$work_root" "db_anchor_inventory_path" "${work_root}/db_anchor_inventory.json"
  mirror_note "$work_root" "anchor_seeds_extracted" "$seed_count"

  echo "logical_group_seeds_path=${work_root}/logical_group_seeds.json"
  echo "db_anchor_inventory_path=${work_root}/db_anchor_inventory.json"
  echo "anchor_seeds_extracted=${seed_count}"
  echo "db_anchor_inventory_count=${inv_count}"
}

cmd_allocate_manifest() {
  local work_root="${1:?WORK_ROOT}"
  local state_path="${2:-${work_root}/state/terraform.tfstate}"
  local strategy cap
  strategy="$(note_or_default "$work_root" "grouping_strategy" "$DBSPLIT_DEFAULT_STRATEGY")"
  cap="$(note_or_default "$work_root" "max_resources_per_appstack" "$DBSPLIT_DEFAULT_CAP")"
  if [ -n "${3:-}" ]; then
    strategy="$3"
  fi
  if [ -n "${4:-}" ]; then
    cap="$4"
  fi

  if [ ! -f "$state_path" ]; then
    echo "allocate_error=state_file_missing path=${state_path}"
    return 1
  fi

  run_py "$work_root" allocate "$work_root" "$state_path" "$strategy" "$cap"
  _mirror_manifest_notes "$work_root" "$strategy" "$cap"
}

_mirror_manifest_notes() {
  local work_root="$1"
  local strategy="$2"
  local cap="$3"
  local manifest_path="${work_root}/logical_group_manifest.json"
  local group_count aggregate
  group_count="$(jq 'length' "$manifest_path")"
  aggregate="$(jq '[.[]] | add' "${work_root}/per_group_resource_counts.json")"

  mirror_note "$work_root" "logical_group_manifest_path" "$manifest_path"
  mirror_note "$work_root" "shard_manifest_path" "${work_root}/shard_manifest.json"
  mirror_note "$work_root" "per_group_resource_counts_path" "${work_root}/per_group_resource_counts.json"
  mirror_note "$work_root" "grouping_strategy" "$strategy"
  mirror_note "$work_root" "max_resources_per_appstack" "$cap"
  mirror_note "$work_root" "logical_group_count" "$group_count"
  mirror_note "$work_root" "aggregate_group_resource_count" "$aggregate"

  echo "logical_group_manifest_path=${manifest_path}"
  echo "logical_group_count=${group_count}"
}

cmd_extract_group_states() {
  local work_root="${1:?WORK_ROOT}"
  local state_path="${2:-${work_root}/state/terraform.tfstate}"
  local manifest_path="${work_root}/logical_group_manifest.json"

  if [ ! -f "$manifest_path" ]; then
    echo "extract_error=missing_logical_group_manifest"
    return 1
  fi

  run_py "$work_root" extract-states "$state_path" "$work_root" "$manifest_path"
  mirror_note "$work_root" "group_state_paths" "${work_root}/group_state_paths.json"
  echo "group_state_paths=${work_root}/group_state_paths.json"
}

cmd_ingest_and_split() {
  local work_root="${1:?WORK_ROOT}"
  local state_uri="${2:-}"
  local strategy="${3:-}"
  local cap="${4:-}"

  cmd_preflight "$work_root"
  cmd_download_state "$work_root" "$state_uri"

  local state_path="${work_root}/state/terraform.tfstate"
  if [ -z "$strategy" ]; then
    strategy="$(note_or_default "$work_root" "grouping_strategy" "$DBSPLIT_DEFAULT_STRATEGY")"
  fi
  if [ -z "$cap" ]; then
    cap="$(note_or_default "$work_root" "max_resources_per_appstack" "$DBSPLIT_DEFAULT_CAP")"
  fi

  cmd_split_manifest "$work_root" "$state_path" "$strategy" "$cap"
}

cmd_split_manifest() {
  local work_root="${1:?WORK_ROOT}"
  local state_path="${2:-${work_root}/state/terraform.tfstate}"
  local strategy cap
  strategy="$(note_or_default "$work_root" "grouping_strategy" "$DBSPLIT_DEFAULT_STRATEGY")"
  cap="$(note_or_default "$work_root" "max_resources_per_appstack" "$DBSPLIT_DEFAULT_CAP")"
  if [ -n "${3:-}" ]; then
    strategy="$3"
  fi
  if [ -n "${4:-}" ]; then
    cap="$4"
  fi

  require_embedded_invocation || return 1

  if [ ! -f "$state_path" ]; then
    echo "split_error=state_file_missing path=${state_path}"
    return 1
  fi

  run_py "$work_root" split "$work_root" "$state_path" "$strategy" "$cap"

  _mirror_manifest_notes "$work_root" "$strategy" "$cap"

  local ok
  ok="$(read_note "$work_root" "count_reconciliation_ok" 2>/dev/null || true)"
  if [ -z "$ok" ] && [ -f "${work_root}/reconcile_result.json" ]; then
    ok="$(jq -r '.count_reconciliation_ok' "${work_root}/reconcile_result.json")"
  fi
  ok="$(printf '%s' "$ok" | tr '[:upper:]' '[:lower:]')"
  mirror_note "$work_root" "count_reconciliation_ok" "$ok"
  mirror_note "$work_root" "group_state_paths" "${work_root}/group_state_paths.json"
  mirror_note "$work_root" "logical_group_seeds_path" "${work_root}/logical_group_seeds.json"
  mirror_note "$work_root" "db_anchor_inventory_path" "${work_root}/db_anchor_inventory.json"

  echo "count_reconciliation_ok=${ok}"
  emit_script_pack_verify "$work_root"
}

# emit_script_pack_verify records script-pack SHA verification and warns on single ungrouped hairballs.
emit_script_pack_verify() {
  local work_root="${1:?WORK_ROOT}"
  local py_path="${work_root}/scripts/allocate_manifest.py"
  local verify_ok="false"

  if verify_allocate_manifest_py "$py_path"; then
    verify_ok="true"
  fi

  mirror_note "$work_root" "script_pack_verify_ok" "$verify_ok"
  mirror_note "$work_root" "script_pack_version" "$SCRIPT_PACK_VERSION"
  echo "script_pack_verify_ok=${verify_ok}"
  echo "script_pack_version=${SCRIPT_PACK_VERSION}"

  if [ "$verify_ok" != "true" ]; then
    mirror_note "$work_root" "blocked:ingest_script_pack_failed" "true"
    echo 'blocked:ingest_script_pack_failed: "true"'
    return 1
  fi

  local group_count monolith_count only_group
  group_count="$(read_note "$work_root" "logical_group_count" 2>/dev/null || true)"
  monolith_count="$(read_note "$work_root" "monolith_resource_count" 2>/dev/null || true)"
  if [ "${group_count:-0}" = "1" ] && [ "${monolith_count:-0}" -gt 5000 ]; then
    only_group="$(jq -r 'keys[0] // empty' "${work_root}/logical_group_manifest.json" 2>/dev/null || true)"
    if [ "$only_group" = "ungrouped" ]; then
      mirror_note "$work_root" "script_pack_drift_possible" "true"
      echo 'script_pack_drift_possible: "true"'
    fi
  fi

  return 0
}

cmd_count_reconcile() {
  local work_root="${1:?WORK_ROOT}"
  local state_path="${2:-${work_root}/state/terraform.tfstate}"
  local manifest_path="${work_root}/logical_group_manifest.json"

  if [ ! -f "$manifest_path" ]; then
    echo "reconcile_error=missing_logical_group_manifest"
    return 1
  fi

  local result ok
  result="$(run_py "$work_root" reconcile "$state_path" "$manifest_path")"
  echo "$result"

  ok="$(printf '%s' "$result" | jq -r '.count_reconciliation_ok')"
  local monolith_count aggregate dupes unallocated
  monolith_count="$(printf '%s' "$result" | jq -r '.monolith_resource_count')"
  aggregate="$(printf '%s' "$result" | jq -r '.aggregate_group_resource_count')"
  dupes="$(printf '%s' "$result" | jq -r '.duplicate_address_count')"
  unallocated="$(printf '%s' "$result" | jq -r '.unallocated_resource_count')"

  mirror_note "$work_root" "monolith_resource_count" "$monolith_count"
  mirror_note "$work_root" "count_reconciliation_ok" "$ok"
  mirror_note "$work_root" "aggregate_group_resource_count" "$aggregate"
  mirror_note "$work_root" "duplicate_address_groups" "$dupes"
  mirror_note "$work_root" "unallocated_resource_count" "$unallocated"

  echo "count_reconciliation_ok=${ok}"
  echo "monolith_resource_count=${monolith_count}"
  echo "aggregate_group_resource_count=${aggregate}"
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    preflight) cmd_preflight "$@" ;;
    download-state) cmd_download_state "$@" ;;
    discover-anchors) cmd_discover_anchors "$@" ;;
    allocate-manifest) cmd_allocate_manifest "$@" ;;
    extract-group-states) cmd_extract_group_states "$@" ;;
    split-manifest) cmd_split_manifest "$@" ;;
    ingest-and-split) cmd_ingest_and_split "$@" ;;
    count-reconcile) cmd_count_reconcile "$@" ;;
    verify-script-pack)
      local work_root="${1:?WORK_ROOT}"
      emit_script_pack_verify "$work_root"
      ;;
    *)
      echo "usage: preflight|download-state|discover-anchors|allocate-manifest|extract-group-states|split-manifest|ingest-and-split|count-reconcile|verify-script-pack WORK_ROOT ..." >&2
      exit 2
      ;;
  esac
}

main "$@"
