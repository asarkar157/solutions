#!/usr/bin/env bash
# General-purpose CCE scan for AIOS Ubuntu agents.
# Env: CCE_USE_CASE, CCE_MAPPER_FILE, CCE_LENS_BASE_URL, CCE_LENS_CHANNEL, CCE_LANGUAGE, CCE_FILTER, SKIP_CCE, CCE_VERSION.
# Usage:
#   cce-scan.sh scan REPO_ROOT [OUTPUT_JSON]
#   cce-scan.sh scan-use-case REPO_ROOT USE_CASE [OUTPUT_JSON]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=cce-common.sh
. "${SCRIPT_DIR}/cce-common.sh"

run_cce_scan() {
  local repo_root="${1:?REPO_ROOT}"
  local output="${2:-}"

  if cce_skip_scan; then
    cce_skipped_report "SKIP_CCE=1"
    return 0
  fi

  if ! ensure_cce; then
    cce_failed_report "cce_not_available"
    return 0
  fi

  local tmp_dir mapper_file filter lang
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  filter="${CCE_FILTER:-cloud}"
  lang="$(cce_language_flag "${CCE_LANGUAGE:-AUTO}")"
  mapper_file=""

  if [ -n "${CCE_MAPPER_FILE:-}" ]; then
    if ! mapper_file="$(cce_resolve_mapper_file "$tmp_dir")"; then
      cce_failed_report "mapper_unavailable"
      return 0
    fi
    filter="${CCE_FILTER:-all}"
  elif [ -n "${CCE_USE_CASE:-}" ]; then
    if cce_use_case_is_builtin "${CCE_USE_CASE}"; then
      filter="${CCE_FILTER:-cloud}"
    elif mapper_file="$(cce_resolve_mapper_file "$tmp_dir")"; then
      filter="${CCE_FILTER:-all}"
    else
      cce_failed_report "mapper_unavailable"
      return 0
    fi
  fi

  local raw="${tmp_dir}/raw.json"
  local -a cce_args=(
    -folder "$repo_root"
    -language "$lang"
    -filter "$filter"
    -format json
    -output "$raw"
    -log-level warn
  )
  if [ -n "$mapper_file" ]; then
    cce_args+=(-mapper-file "$mapper_file")
  fi

  if ! cce "${cce_args[@]}" 2>"${tmp_dir}/cce.err"; then
    cce_failed_report "cce_run_failed"
    return 0
  fi
  if [ ! -f "$raw" ]; then
    cce_failed_report "cce_empty_output"
    return 0
  fi

  local report
  report="$(cce_normalize_report "$raw" "ok" "${CCE_USE_CASE:-}")"
  if [ -n "$output" ]; then
    mkdir -p "$(dirname "$output")"
    printf '%s' "$report" >"$output"
  fi
  printf '%s' "$report"
}

case "${1:-}" in
  scan)
    shift
    run_cce_scan "$@"
    ;;
  scan-use-case)
    shift
    export CCE_USE_CASE="${2:?USE_CASE}"
    run_cce_scan "${1:?REPO_ROOT}" "${3:-}"
    ;;
  *)
    echo "usage: cce-scan.sh scan REPO_ROOT [OUTPUT_JSON]" >&2
    echo "       cce-scan.sh scan-use-case REPO_ROOT USE_CASE [OUTPUT_JSON]" >&2
    exit 1
    ;;
esac
