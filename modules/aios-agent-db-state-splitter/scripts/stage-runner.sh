#!/usr/bin/env bash
# db-state-splitter stage runner — invoke ONLY via _embed_dbsplit_run (DBSPLIT_EMBEDDED=1).
# Direct `bash $WORK_ROOT/scripts/stage-runner.sh` is rejected (agent script drift).
# Usage: DBSPLIT_EMBEDDED=1 bash -s <command> [args...] << 'DBSPLIT_STAGE_RUNNER' ... DBSPLIT_STAGE_RUNNER
set -euo pipefail

SCRIPT_PACK_VERSION="20260531.32"
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
  local py log_file quiet
  py="$(resolve_allocate_py "$work_root")"
  quiet="${DBSPLIT_QUIET_PY:-}"
  log_file="${work_root}/.py-run.log"
  if [ "$quiet" = "1" ]; then
    python3 "$py" "$@" >>"$log_file" 2>&1
    return $?
  fi
  python3 "$py" "$@"
}

emit_ingest_handoff_summary() {
  local work_root="${1:?WORK_ROOT}"
  local notes="${work_root}/notes.json"
  local handoff_dir="${work_root}/.work"
  local handoff_file="${handoff_dir}/ingest-handoff.txt"
  if [ ! -f "$notes" ]; then
    echo "handoff_error=missing_notes_json"
    return 1
  fi
  mkdir -p "$handoff_dir"
  jq -r '
    "count_reconciliation_ok=\(.count_reconciliation_ok // "false")",
    "logical_group_count=\(.logical_group_count // "0")",
    "logical_group_manifest_path=\(.logical_group_manifest_path // "")",
    "group_state_paths=\(.group_state_paths // "")",
    "monolith_resource_count=\(.monolith_resource_count // "0")",
    "aggregate_group_resource_count=\(.aggregate_group_resource_count // "0")",
    "monolith_state_local_path=\(.monolith_state_local_path // "")",
    "script_pack_version=\(.script_pack_version // "")",
    "script_pack_verify_ok=\(.script_pack_verify_ok // "false")"
  ' "$notes" | tee "$handoff_file"
  mirror_note "$work_root" "ingest_handoff_path" "$handoff_file"
  echo "ingest_handoff_path=${handoff_file}"
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
  if [ -z "$uri" ] && [ -n "${MONOLITH_URI:-}" ]; then
    uri="$MONOLITH_URI"
  fi
  printf '%s' "$uri"
}

# ensure_monolith_uri_from_work_root loads MONOLITH_URI from spawn pre-write file or notes.json.
# Exists so ingest-and-split survives runners that paste the embed without export (trace 8c7ea4ad).
ensure_monolith_uri_from_work_root() {
  local work_root="${1:?WORK_ROOT}"
  if [ -n "${MONOLITH_URI:-}" ]; then
    return 0
  fi
  local uri_file="${work_root}/.work/spawn_monolith_uri"
  if [ -f "$uri_file" ]; then
    export MONOLITH_URI="$(tr -d '\n\r' <"$uri_file")"
    echo "MONOLITH_URI_from_spawn_file=true"
    return 0
  fi
  if [ -f "${work_root}/notes.json" ]; then
    local raw
    raw="$(jq -r '.monolith_state_uri // .tfstate_file // empty' "${work_root}/notes.json" 2>/dev/null || true)"
    raw="${raw#monolith_state_uri=}"
    if [ -n "$raw" ]; then
      export MONOLITH_URI="$raw"
      echo "MONOLITH_URI_from_notes_fallback=true"
      return 0
    fi
  fi
  return 1
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
  mirror_note "$work_root" "ingest_stage_progress" "download_complete"

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

  cmd_preflight "$work_root" >/dev/null
  ensure_monolith_uri_from_work_root "$work_root" || true
  state_uri="$(resolve_state_uri "$state_uri")"
  if [ -z "$state_uri" ]; then
    echo "download_error=missing_monolith_state_uri_or_tfstate_file"
    return 1
  fi
  export MONOLITH_URI="$state_uri"
  cmd_download_state "$work_root" "$state_uri" >/dev/null
  mirror_note "$work_root" "ingest_stage_progress" "split_start"

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

  DBSPLIT_QUIET_PY=1 run_py "$work_root" split "$work_root" "$state_path" "$strategy" "$cap"

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
  emit_ingest_handoff_summary "$work_root"
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

bootstrap_gh() {
  local git_token="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
  export GIT_TOKEN="$git_token" GH_TOKEN="$git_token" GITHUB_TOKEN="$git_token"
  export GIT_TERMINAL_PROMPT=0
  if [ -z "$git_token" ]; then
    echo "gh_env_present=false"
    return 1
  fi
  echo "gh_env_present=true"
  if command -v gh >/dev/null 2>&1; then
    gh auth setup-git 2>/dev/null || true
  fi
  git config --global user.name "stackgen-db-state-splitter"
  git config --global user.email "db-state-splitter@stackgen.local"
}

git_clone_url() {
  local url="${1:?REPO_CLONE_URL}"
  local git_token="${GIT_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
  if [[ "$url" =~ ^git@ ]]; then
    printf '%s' "$url"
    return 0
  fi
  if [[ "$url" =~ ^https://[^/@]+@ ]]; then
    printf '%s' "$url"
    return 0
  fi
  if [ -n "$git_token" ] && [[ "$url" =~ ^https://github\.com/ ]]; then
    printf 'https://x-access-token:%s@github.com/%s' "$git_token" "${url#https://github.com/}"
    return 0
  fi
  printf '%s' "$url"
}

resolve_repo_dir() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="$work_root/repo"
  local legacy_dir="$work_root/repo_clone"
  if [ -d "$repo_dir/.git" ]; then
    printf '%s' "$repo_dir"
    return 0
  fi
  if [ -d "$legacy_dir/.git" ]; then
    ln -sfn "$legacy_dir" "$repo_dir" 2>/dev/null || true
    mirror_note "$work_root" "repo_clone_path" "$repo_dir"
    printf '%s' "$repo_dir"
    return 0
  fi
  printf '%s' "$repo_dir"
}

repo_full_name_from_url() {
  local url="${1:?URL}"
  url="${url%.git}"
  if [[ "$url" =~ github\.com[:/]([^/]+/[^/]+)$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  printf '%s' "$url"
}

cmd_clone_iac_repo() {
  local work_root="${1:?WORK_ROOT}"
  local repo_url="${2:-}"
  local default_branch="${3:-main}"

  if [ -z "$repo_url" ]; then
    repo_url="$(read_note "$work_root" "iac_repository_url" 2>/dev/null || true)"
  fi
  if [ -z "$repo_url" ] && [ -n "${IAC_REPOSITORY_URL:-}" ]; then
    repo_url="$IAC_REPOSITORY_URL"
  fi
  if [ -z "$repo_url" ]; then
    mirror_note "$work_root" "repo_clone_path" "skipped_no_iac_repository_url_provided"
    echo "repo_clone_path=skipped_no_iac_repository_url_provided"
    return 1
  fi

  mirror_note "$work_root" "iac_repository_url" "$repo_url"
  mirror_note "$work_root" "default_branch" "$default_branch"
  bootstrap_gh || true

  local repo_dir clone_url
  repo_dir="$(resolve_repo_dir "$work_root")"
  mkdir -p "$(dirname "$repo_dir")"
  clone_url="$(git_clone_url "$repo_url")"

  if [ ! -d "$repo_dir/.git" ]; then
    rm -rf "$repo_dir"
    git clone --depth 1 --branch "$default_branch" "$clone_url" "$repo_dir" \
      || git clone --depth 1 "$clone_url" "$repo_dir"
  fi

  cd "$repo_dir"
  git fetch origin "$default_branch" 2>/dev/null || true
  git checkout "$default_branch" 2>/dev/null || git checkout -B "$default_branch"
  git pull --ff-only origin "$default_branch" 2>/dev/null || true

  mirror_note "$work_root" "repo_clone_path" "$repo_dir"
  echo "repo_clone_path=${repo_dir}"
  echo "iac_repository_url=${repo_url}"
}

cmd_registry_scaffold() {
  local work_root="${1:?WORK_ROOT}"
  require_embedded_invocation || return 1
  DBSPLIT_QUIET_PY=1 run_py "$work_root" scaffold-registry "$work_root"
  mirror_note "$work_root" "registry_mapping_report" "${work_root}/registry_mapping_report.json"
  mirror_note "$work_root" "orphans_bundle" "${work_root}/orphans_bundle.json"
  mirror_note "$work_root" "stage_summary:registry-and-import-codegen" "ok"
  mirror_note "$work_root" "iac_pr_fast_path" "true"
}

cmd_sync_groups_to_repo() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir
  repo_dir="$(resolve_repo_dir "$work_root")"
  if [ ! -d "$repo_dir/.git" ]; then
    echo "sync_error=no_clone"
    return 1
  fi
  if [ ! -d "${work_root}/groups" ]; then
    echo "sync_error=no_groups_dir"
    return 1
  fi
  rm -rf "${repo_dir}/groups"
  cp -a "${work_root}/groups" "${repo_dir}/groups"
  local group_count
  group_count="$(find "${repo_dir}/groups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  mirror_note "$work_root" "groups_synced_to_repo" "$group_count"
  echo "groups_synced_to_repo=${group_count}"
}

resolve_tofu_bin() {
  if command -v tofu >/dev/null 2>&1; then
    command -v tofu
    return 0
  fi
  if command -v terraform >/dev/null 2>&1; then
    command -v terraform
    return 0
  fi
  return 1
}

sample_group_ids_json() {
  local work_root="${1:?WORK_ROOT}"
  local manifest_path="${work_root}/logical_group_manifest.json"
  local group_count sample_size
  group_count="$(jq 'length' "$manifest_path")"
  if [ "$group_count" -gt 40 ]; then
    sample_size=20
    mirror_note "$work_root" "large_state_sample_mode" "true"
    mirror_note "$work_root" "large_state_sample_size" "$sample_size"
  else
    sample_size="$group_count"
    mirror_note "$work_root" "large_state_sample_mode" "false"
    mirror_note "$work_root" "large_state_sample_size" "$sample_size"
  fi
  jq -c --argjson n "$sample_size" 'keys | sort | .[0:$n]' "$manifest_path"
}

cmd_prepare_parallel_artifacts() {
  local work_root="${1:?WORK_ROOT}"
  require_embedded_invocation || return 1

  local manifest_path="${work_root}/logical_group_manifest.json"
  if [ ! -f "$manifest_path" ]; then
    echo "prepare_error=missing_logical_group_manifest"
    return 1
  fi

  local sample_ids sample_path payloads_path idmap_path
  sample_ids="$(sample_group_ids_json "$work_root")"
  sample_path="${work_root}/sample_group_ids.json"
  payloads_path="${work_root}/batch_payloads.json"
  idmap_path="${work_root}/identifier_map.json"

  printf '%s\n' "$sample_ids" >"$sample_path"
  mirror_note "$work_root" "large_state_sample_group_ids" "$sample_ids"

  jq --argjson ids "$sample_ids" '
    [ . as $m | $ids[] | {
        group_id: .,
        cloud_hint: ($m[.].cloud_hint // "aws"),
        resource_addresses: ($m[.].resource_addresses // [])
      } ]
  ' "$manifest_path" >"$payloads_path"

  if [ -f "${work_root}/registry_mapping_report.json" ]; then
    jq '
      if type == "object" and has("address_to_identifier") then .address_to_identifier
      elif type == "object" and has("identifier_map") then .identifier_map
      else {} end
    ' "${work_root}/registry_mapping_report.json" >"$idmap_path" 2>/dev/null \
      || echo '{}' >"$idmap_path"
  else
    echo '{}' >"$idmap_path"
  fi

  mirror_note "$work_root" "sample_group_ids_path" "$sample_path"
  mirror_note "$work_root" "batch_payloads_path" "$payloads_path"
  mirror_note "$work_root" "identifier_map_path" "$idmap_path"
  mirror_note "$work_root" "stage_summary:prepare-parallel-artifacts" "ok"

  echo "sample_group_ids_path=${sample_path}"
  echo "batch_payloads_path=${payloads_path}"
  echo "identifier_map_path=${idmap_path}"
  echo "large_state_sample_group_ids=${sample_ids}"
}

fix_generated_tf_name_conflicts() {
  local gen_tf="${1:?generated.tf}"
  [ -f "$gen_tf" ] || return 0
  python3 - "$gen_tf" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
# Drop name_prefix when the same block also sets name (AWS mutual exclusion).
out = []
for block in re.split(r"(?=resource\s+\"[^\"]+\"\s+\"[^\"]+\"\s+\{)", text):
    if re.search(r"\bname_prefix\s*=", block) and re.search(r"\bname\s*=", block):
        block = re.sub(r"^\s*name_prefix\s*=.*\n", "", block, flags=re.M)
    out.append(block)
open(path, "w", encoding="utf-8").write("".join(out))
PY
}

hydrate_one_group() {
  local work_root="${1:?WORK_ROOT}"
  local group_id="${2:?GROUP_ID}"
  local tofu_bin="${3:?TOFU}"
  local groups_dir="${work_root}/groups/${group_id}"
  local gen_tf="${groups_dir}/generated.tf"
  local status_json plan_out remaining

  if [ ! -d "$groups_dir" ]; then
    echo "group_skip=${group_id} reason=no_group_dir"
    return 1
  fi

  cd "$groups_dir"
  "$tofu_bin" init -input=false -no-color >/dev/null 2>&1 || {
    mirror_note "$work_root" "hcl_hydration_status:${group_id}" "{\"plan_no_changes\":false,\"failure_reason\":\"init_failed\"}"
    return 1
  }

  "$tofu_bin" plan -generate-config-out=generated.tf -input=false -lock=false -no-color \
    -out=hydrate.tfplan >/dev/null 2>&1 || true
  if [ -f "$gen_tf" ]; then
    fix_generated_tf_name_conflicts "$gen_tf"
    "$tofu_bin" fmt -no-color "$gen_tf" >/dev/null 2>&1 || true
  fi

  plan_out="$("$tofu_bin" plan -input=false -lock=false -no-color -out=verify.tfplan 2>&1)" || true
  remaining="$(printf '%s' "$plan_out" | grep -Eo '[0-9]+ to (add|change|destroy)' | head -1 || true)"
  if printf '%s' "$plan_out" | grep -q 'No changes'; then
    status_json="{\"generated_tf_path\":\"${gen_tf}\",\"plan_no_changes\":true,\"remaining_actions\":\"0\",\"attempt\":1}"
    mirror_note "$work_root" "hcl_hydration_status:${group_id}" "$status_json"
    echo "group_ok=${group_id}"
    return 0
  fi

  status_json="{\"generated_tf_path\":\"${gen_tf}\",\"plan_no_changes\":false,\"remaining_actions\":\"${remaining:-unknown}\",\"attempt\":1}"
  mirror_note "$work_root" "hcl_hydration_status:${group_id}" "$status_json"
  echo "group_fail=${group_id} remaining=${remaining:-unknown}"
  return 1
}

cmd_hydrate_and_plan_matrix() {
  local work_root="${1:?WORK_ROOT}"
  require_embedded_invocation || return 1

  local tofu_bin
  if ! tofu_bin="$(resolve_tofu_bin)"; then
    mirror_note "$work_root" "blocked:ubuntu_infra_tofu_missing" "true"
    mirror_note "$work_root" "multi_plan_zero_diff_ok" "false"
    echo 'blocked:ubuntu_infra_tofu_missing: "true"'
    echo 'multi_plan_zero_diff_ok: "false"'
    return 1
  fi

  local sample_path="${work_root}/sample_group_ids.json"
  if [ ! -f "$sample_path" ]; then
    cmd_prepare_parallel_artifacts "$work_root" || return 1
  fi

  local ok_count fail_count total
  ok_count=0
  fail_count=0
  total=0

  while IFS= read -r group_id; do
    [ -n "$group_id" ] || continue
    total=$((total + 1))
    if hydrate_one_group "$work_root" "$group_id" "$tofu_bin"; then
      ok_count=$((ok_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi
  done < <(jq -r '.[]' "$sample_path")

  local multi_ok="false"
  if [ "$total" -gt 0 ] && [ "$fail_count" -eq 0 ]; then
    multi_ok="true"
  fi

  mirror_note "$work_root" "multi_plan_zero_diff_ok" "$multi_ok"
  mirror_note "$work_root" "stage_summary:shell-converge-matrix" "ok_groups=${ok_count} fail_groups=${fail_count}"
  echo "hydrate_ok_groups=${ok_count}"
  echo "hydrate_fail_groups=${fail_count}"
  echo "multi_plan_zero_diff_ok: \"${multi_ok}\""
}

cmd_commit_pr() {
  local work_root="${1:?WORK_ROOT}"
  local repo_url="${2:-}"
  local default_branch="${3:-main}"
  local workflow_run_id="${4:-}"

  if [ -z "$repo_url" ]; then
    repo_url="$(read_note "$work_root" "iac_repository_url" 2>/dev/null || true)"
  fi
  if [ -z "$default_branch" ] || [ "$default_branch" = "main" ]; then
    default_branch="$(note_or_default "$work_root" "default_branch" "main")"
  fi
  if [ -z "$workflow_run_id" ]; then
    workflow_run_id="${WORKFLOW_RUN_ID:-$(read_note "$work_root" "workflow_run_id" 2>/dev/null || true)}"
  fi
  if [ -z "$workflow_run_id" ]; then
    workflow_run_id="$(date +%Y%m%d%H%M%S)"
  fi

  if ! bootstrap_gh; then
    mirror_note "$work_root" "pr_blocker" "auth"
    echo "pr_blocker=auth"
    return 1
  fi

  local repo_dir repo_full branch pr_title pr_body_file
  repo_dir="$(resolve_repo_dir "$work_root")"
  if [ ! -d "$repo_dir/.git" ]; then
    mirror_note "$work_root" "pr_blocker" "no_clone"
    echo "pr_error=no_clone"
    return 1
  fi

  repo_full="$(repo_full_name_from_url "$repo_url")"
  branch="split/${workflow_run_id}"

  cd "$repo_dir"
  git add -A
  if git diff --cached --quiet; then
    echo "pr_error=nothing_to_commit"
    return 1
  fi

  git switch -c "$branch" 2>/dev/null || git switch "$branch"
  pr_title="Split monolith tfstate (${workflow_run_id})"
  pr_body_file="${work_root}/.work/pr-body.md"
  mkdir -p "${work_root}/.work"
  {
    echo "# Monolith state split"
    echo
    echo "Automated split from db-monorepo-state-split-convergence workflow."
    echo
    echo "- workflow_run_id: \`${workflow_run_id}\`"
    echo "- groups: \`$(read_note "$work_root" "logical_group_count" 2>/dev/null || echo unknown)\`"
    echo "- script_pack: \`${SCRIPT_PACK_VERSION}\`"
  } >"$pr_body_file"

  git commit -m "split: db-monorepo state shards (${workflow_run_id})" || {
    echo "pr_error=nothing_to_commit"
    return 1
  }

  if ! git push -u origin HEAD 2>"${work_root}/.work/push.err"; then
    mirror_note "$work_root" "pr_blocker" "push_failed"
    echo "pr_blocker=push_failed"
    cat "${work_root}/.work/push.err" >&2 || true
    return 1
  fi

  local pr_url=""
  pr_url="$(gh pr list --repo "$repo_full" --head "$branch" --json url -q '.[0].url' 2>/dev/null || true)"
  if [ -z "$pr_url" ] || [ "$pr_url" = "null" ]; then
    pr_url="$(gh pr create --repo "$repo_full" --base "$default_branch" --head "$branch" \
      --title "$pr_title" --body-file "$pr_body_file")"
  fi

  mirror_note "$work_root" "working_branch" "$branch"
  mirror_note "$work_root" "pr_url" "$pr_url"
  mirror_note "$work_root" "iac_pr_url" "$pr_url"
  mirror_note "$work_root" "iac_push_status" "ok"
  mirror_note "$work_root" "iac_push_branch" "$branch"
  mirror_note "$work_root" "stage_summary:final-gate-and-memory" "ok"
  mirror_note "$work_root" "multi_plan_zero_diff_ok" "skipped_iac_pr_fast_path"
  echo "working_branch=${branch}"
  echo "pr_url=${pr_url}"
  echo "iac_pr_url=${pr_url}"
}

cmd_iac_pr_pipeline() {
  local work_root="${1:?WORK_ROOT}"
  local repo_url="${2:-${IAC_REPOSITORY_URL:-}}"
  local default_branch="${3:-${DEFAULT_BRANCH:-main}}"
  local workflow_run_id="${4:-${WORKFLOW_RUN_ID:-}}"

  require_embedded_invocation || return 1

  local reconcile_ok
  reconcile_ok="$(read_note "$work_root" "count_reconciliation_ok" 2>/dev/null || true)"
  if [ "$reconcile_ok" != "true" ]; then
    echo "iac_pr_error=count_reconciliation_not_ok"
    return 1
  fi

  if [ -n "$workflow_run_id" ]; then
    mirror_note "$work_root" "workflow_run_id" "$workflow_run_id"
  fi

  cmd_registry_scaffold "$work_root"
  cmd_prepare_parallel_artifacts "$work_root"
  cmd_clone_iac_repo "$work_root" "$repo_url" "$default_branch"
  cmd_sync_groups_to_repo "$work_root"
  cmd_commit_pr "$work_root" "$repo_url" "$default_branch" "$workflow_run_id"
  echo "iac_pr_fast_path=true"
  jq -r '"pr_url=\(.pr_url // "")", "iac_pr_url=\(.iac_pr_url // "")", "groups_synced_to_repo=\(.groups_synced_to_repo // "0")"' \
    "${work_root}/notes.json"
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
    emit-ingest-handoff) emit_ingest_handoff_summary "${1:?WORK_ROOT}" ;;
    count-reconcile) cmd_count_reconcile "$@" ;;
    verify-script-pack)
      local work_root="${1:?WORK_ROOT}"
      emit_script_pack_verify "$work_root"
      ;;
    clone-iac-repo) cmd_clone_iac_repo "$@" ;;
    registry-scaffold) cmd_registry_scaffold "$@" ;;
    sync-groups-to-repo) cmd_sync_groups_to_repo "$@" ;;
    commit-pr) cmd_commit_pr "$@" ;;
    iac-pr-pipeline) cmd_iac_pr_pipeline "$@" ;;
    prepare-parallel-artifacts) cmd_prepare_parallel_artifacts "$@" ;;
    hydrate-and-plan-matrix) cmd_hydrate_and_plan_matrix "$@" ;;
    *)
      echo "usage: preflight|download-state|discover-anchors|allocate-manifest|extract-group-states|split-manifest|ingest-and-split|emit-ingest-handoff|count-reconcile|verify-script-pack|clone-iac-repo|registry-scaffold|sync-groups-to-repo|commit-pr|iac-pr-pipeline|prepare-parallel-artifacts|hydrate-and-plan-matrix WORK_ROOT ..." >&2
      exit 2
      ;;
  esac
}

main "$@"
