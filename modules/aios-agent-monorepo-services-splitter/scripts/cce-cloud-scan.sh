#!/usr/bin/env bash
# Run CCE (Code Context Engine) cloud entitlement scan on a cloned repo checkout.
# Writes JSON to stdout; non-zero exit only on install/IO failures (empty entitlements is ok).
set -euo pipefail

CCE_VERSION="${CCE_VERSION:-0.0.4}"
CCE_MAX_ENTITLEMENTS="${CCE_MAX_ENTITLEMENTS:-500}"
USER_LOCAL_BIN="${HOME}/.local/bin"

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

# Map boundary-scan language tags to CCE -language values.
cce_language_for() {
  case "${1:-}" in
    go) echo "GO" ;;
    java) echo "JAVA" ;;
    typescript) echo "JAVASCRIPT" ;;
    *) echo "" ;;
  esac
}

# Merge per-language CCE JSON reports into one object on stdout.
run_cce_cloud_scan() {
  local repo_root="${1:?REPO_ROOT}"
  local languages_json="${2:?LANGUAGES_JSON}"

  if [ "${MONOREPO_SPLIT_SKIP_CCE:-}" = "1" ]; then
    jq -n \
      --arg version "$CCE_VERSION" \
      '{scan_status: "skipped", reason: "MONOREPO_SPLIT_SKIP_CCE=1", cce_version: $version, entitlements: [], summary: {total_entitlements: 0, by_provider: {}}}'
    return 0
  fi

  if ! ensure_cce; then
    jq -n \
      --arg version "$CCE_VERSION" \
      '{scan_status: "failed", reason: "cce_not_available", cce_version: $version, entitlements: [], summary: {total_entitlements: 0, by_provider: {}}}'
    return 0
  fi

  local tmp_dir merged
  tmp_dir="$(mktemp -d)"
  merged="${tmp_dir}/merged.json"
  echo '{"entitlements":[]}' >"$merged"

  local lang cce_lang out_file
  while IFS= read -r lang; do
    cce_lang="$(cce_language_for "$lang")"
    if [ -z "$cce_lang" ]; then
      continue
    fi
    out_file="${tmp_dir}/cce-${lang}.json"
    if ! cce \
      -folder "$repo_root" \
      -language "$cce_lang" \
      -filter cloud \
      -format json \
      -output "$out_file" \
      -log-level warn 2>"${tmp_dir}/cce-${lang}.err"; then
      echo "cce_scan_warn=language_failed language=${lang} stderr=$(tr '\n' ' ' <"${tmp_dir}/cce-${lang}.err" | head -c 200)" >&2
      continue
    fi
    if [ ! -f "$out_file" ]; then
      continue
    fi
    jq -s '
      .[0] as $acc | .[1] as $part |
      {
        entitlements: (($acc.entitlements // []) + ($part.entitlements // [])),
        files_scanned: (($acc.files_scanned // 0) + ($part.files_scanned // 0))
      }
    ' "$merged" "$out_file" >"${merged}.tmp" && mv "${merged}.tmp" "$merged"
  done < <(echo "$languages_json" | jq -r '.[]')

  local total truncated_json
  total="$(jq '.entitlements | length' "$merged")"
  if [ "$total" -gt "$CCE_MAX_ENTITLEMENTS" ]; then
    truncated_json=true
  else
    truncated_json=false
  fi

  jq \
    --arg version "$CCE_VERSION" \
    --argjson truncated "$truncated_json" \
    --argjson max "$CCE_MAX_ENTITLEMENTS" \
    --slurpfile merged "$merged" '
    ($merged[0].entitlements // []) as $all |
    (if $truncated then $all[0:$max] else $all end) as $ents |
    {
      scan_status: "ok",
      cce_version: $version,
      files_scanned: ($merged[0].files_scanned // 0),
      entitlements_truncated: $truncated,
      entitlements_total: ($all | length),
      entitlements: $ents,
      summary: {
        total_entitlements: ($ents | length),
        by_provider: (
          $ents | group_by(.provider) | map({key: .[0].provider, value: length}) | from_entries
        )
      }
    }
  ' <<<"{}"

  rm -rf "$tmp_dir"
}

case "${1:-}" in
  scan)
    shift
    run_cce_cloud_scan "$@"
    ;;
  *)
    echo "usage: cce-cloud-scan.sh scan REPO_ROOT LANGUAGES_JSON" >&2
    exit 1
    ;;
esac
