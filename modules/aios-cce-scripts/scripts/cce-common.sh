#!/usr/bin/env bash
# Shared CCE helpers for AIOS Ubuntu integrations (sourced by cce-scan.sh / cce-pr-delta.sh).
set -euo pipefail

CCE_VERSION="${CCE_VERSION:-0.0.4}"
CCE_MAX_ENTITLEMENTS="${CCE_MAX_ENTITLEMENTS:-500}"
CCE_LENS_BASE_URL="${CCE_LENS_BASE_URL:-https://releases.stackgen.com/cce/lenses}"
CCE_LENS_CHANNEL="${CCE_LENS_CHANNEL:-latest}"
USER_LOCAL_BIN="${HOME}/.local/bin"

cce_skip_scan() {
  [ "${SKIP_CCE:-}" = "1" ] || [ "${MONOREPO_SPLIT_SKIP_CCE:-}" = "1" ]
}

# Built-in mapper use cases (CCE definition.yaml); do not pass -mapper-file.
cce_use_case_is_builtin() {
  case "${1:-}" in
    change-control | cloud-entitlements | pre-deploy-iam-review) return 0 ;;
  esac
  return 1
}

# Public lens URL: .../cce/lenses/<use-case>/<channel>/<use-case>_lenses.yaml
cce_lens_download_url() {
  local use_case="${1:?USE_CASE}"
  local lens_name="${use_case}_lenses.yaml"
  printf '%s/%s/%s/%s' "${CCE_LENS_BASE_URL%/}" "$use_case" "${CCE_LENS_CHANNEL}" "$lens_name"
}

ensure_cce() {
  export PATH="${USER_LOCAL_BIN}:${PATH}"
  if command -v cce >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1; then
    echo "cce_scan_error=missing_curl" >&2
    return 1
  fi

  local arch cce_arch os_name
  arch="$(uname -m)"
  case "$arch" in
    x86_64) cce_arch=amd64 ;;
    aarch64 | arm64) cce_arch=arm64 ;;
    *)
      echo "cce_scan_error=unsupported_arch arch=${arch}" >&2
      return 1
      ;;
  esac
  case "$(uname -s)" in
    Linux) os_name=linux ;;
    Darwin) os_name=darwin ;;
    *)
      echo "cce_scan_error=unsupported_os os=$(uname -s)" >&2
      return 1
      ;;
  esac

  local url="https://releases.stackgen.com/binaries/cce/v${CCE_VERSION}/cce_${CCE_VERSION}_${os_name}_${cce_arch}.tar.gz"
  mkdir -p "$USER_LOCAL_BIN"
  if ! curl -fsSL -o /tmp/cce.tgz "$url"; then
    echo "cce_scan_error=download_failed version=${CCE_VERSION} arch=${cce_arch}" >&2
    return 1
  fi
  tar -xzf /tmp/cce.tgz -C "$USER_LOCAL_BIN" cce
  rm -f /tmp/cce.tgz
  chmod +x "${USER_LOCAL_BIN}/cce"
  export PATH="${USER_LOCAL_BIN}:${PATH}"
  command -v cce >/dev/null 2>&1
}

# Resolve -mapper-file value: local path, HTTPS URL, or releases lens URL for CCE_USE_CASE.
# CCE downloads remote mapper YAML itself when given an https:// URL.
cce_resolve_mapper_file() {
  local _work_dir="${1:?TMP_DIR}"

  if [ -n "${CCE_MAPPER_FILE:-}" ]; then
    if [ -f "${CCE_MAPPER_FILE}" ]; then
      printf '%s' "${CCE_MAPPER_FILE}"
      return 0
    fi
    case "${CCE_MAPPER_FILE}" in
      https://*)
        printf '%s' "${CCE_MAPPER_FILE}"
        return 0
        ;;
    esac
    echo "cce_scan_error=mapper_file_not_found path=${CCE_MAPPER_FILE}" >&2
    return 1
  fi

  if [ -z "${CCE_USE_CASE:-}" ]; then
    return 1
  fi

  if cce_use_case_is_builtin "${CCE_USE_CASE}"; then
    return 1
  fi

  printf '%s' "$(cce_lens_download_url "${CCE_USE_CASE}")"
}

cce_language_flag() {
  local lang="${1:-AUTO}"
  case "$lang" in
    GO | JAVA | JAVASCRIPT | PYTHON | AUTO) printf '%s' "$lang" ;;
    go) printf '%s' "GO" ;;
    java) printf '%s' "JAVA" ;;
    typescript | javascript | ts | js) printf '%s' "JAVASCRIPT" ;;
    python | py) printf '%s' "PYTHON" ;;
    *) printf '%s' "AUTO" ;;
  esac
}

# Normalize raw CCE JSON file into standard report object on stdout.
cce_normalize_report() {
  local raw_file="${1:?RAW}"
  local scan_status="${2:-ok}"
  local use_case="${3:-}"
  jq \
    --arg version "$CCE_VERSION" \
    --arg status "$scan_status" \
    --arg use_case "$use_case" \
    --argjson max "$CCE_MAX_ENTITLEMENTS" \
    --slurpfile raw "$raw_file" '
    ($raw[0].entitlements // []) as $all |
    (if ($all | length) > $max then $all[0:$max] else $all end) as $ents |
    {
      scan_status: $status,
      cce_version: $version,
      cce_use_case: (if $use_case == "" then null else $use_case end),
      files_scanned: ($raw[0].files_scanned // 0),
      entitlements_truncated: (($all | length) > $max),
      entitlements_total: ($all | length),
      entitlements: $ents,
      summary: {
        total_entitlements: ($ents | length),
        by_provider: (
          $ents | group_by(.provider) | map({key: (.[0].provider // "unknown"), value: length}) | from_entries
        )
      }
    }
  ' <<<"{}"
}

cce_failed_report() {
  local reason="${1:?REASON}"
  jq -n \
    --arg version "$CCE_VERSION" \
    --arg reason "$reason" \
    --arg use_case "${CCE_USE_CASE:-}" \
    '{
      scan_status: "failed",
      reason: $reason,
      cce_version: $version,
      cce_use_case: (if $use_case == "" then null else $use_case end),
      entitlements: [],
      summary: { total_entitlements: 0, by_provider: {} }
    }'
}

cce_skipped_report() {
  local reason="${1:-SKIP_CCE}"
  jq -n \
    --arg version "$CCE_VERSION" \
    --arg reason "$reason" \
    '{
      scan_status: "skipped",
      reason: $reason,
      cce_version: $version,
      entitlements: [],
      summary: { total_entitlements: 0, by_provider: {} }
    }'
}
