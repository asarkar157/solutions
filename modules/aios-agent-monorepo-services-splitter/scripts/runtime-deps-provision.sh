#!/usr/bin/env bash
# Provision language runtimes on Ubuntu runners (root/sudo) and run optional baseline tests.
# Runners have admin privileges — never defer Java/Go/Node with "not available in runner env".
set -euo pipefail

SCRIPT_PACK_VERSION="${SCRIPT_PACK_VERSION:-20260602.14}"

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

apt_run() {
  if [ "$(id -u)" -eq 0 ]; then
    apt-get "$@"
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo -n apt-get "$@" 2>/dev/null && return 0
    sudo apt-get "$@"
    return 0
  fi
  apt-get "$@"
}

apt_retry() {
  # Ubuntu runners can hit transient dpkg/apt locks when multiple processes
  # provision dependencies concurrently. Retry with backoff instead of skipping
  # baseline tests or failing the stage on a temporary lock.
  local tries="${APT_RETRY_TRIES:-8}"
  local sleep_s="${APT_RETRY_SLEEP_SECONDS:-3}"
  local i=1

  while [ "$i" -le "$tries" ]; do
    local out rc
    out="$(mktemp)"
    set +e
    # Dpkg::Lock::Timeout handles the common "frontend lock held" case.
    apt_run -o Dpkg::Lock::Timeout=60 "$@" >"$out" 2>&1
    rc=$?
    set -e

    if [ "$rc" -eq 0 ]; then
      rm -f "$out"
      return 0
    fi

    if grep -qiE 'Could not get lock|dpkg frontend lock|Unable to acquire the dpkg frontend lock|Unable to acquire the dpkg lock|Waiting for cache lock' "$out"; then
      echo "apt_retry=lock_detected attempt=${i}/${tries} sleep_seconds=${sleep_s}" >&2
      cat "$out" >&2 || true
      rm -f "$out"
      sleep "$sleep_s"
      # Linear backoff capped to 20s.
      if [ "$sleep_s" -lt 20 ]; then
        sleep_s=$((sleep_s + 2))
      fi
      i=$((i + 1))
      continue
    fi

    cat "$out" >&2 || true
    rm -f "$out"
    return "$rc"
  done

  echo "apt_retry=exhausted tries=${tries}" >&2
  return 1
}

detect_java_version() {
  local repo="${1:?REPO_ROOT}"
  local version=""

  if [ -f "$repo/.java-version" ]; then
    version="$(tr -d 'v' <"$repo/.java-version" | head -1 | cut -d. -f1)"
  fi
  if [ -z "$version" ] && [ -f "$repo/.tool-versions" ]; then
    version="$(grep -E '^java ' "$repo/.tool-versions" 2>/dev/null | awk '{print $2}' | tr -d 'v' | cut -d. -f1 || true)"
  fi
  if [ -z "$version" ] && [ -f "$repo/gradle.properties" ]; then
    version="$(grep -E '^org\.gradle\.java\.home=' "$repo/gradle.properties" 2>/dev/null | grep -oE 'jdk-([0-9]+)' | head -1 | cut -d- -f2 || true)"
  fi
  if [ -z "$version" ]; then
    local gradle_file="$repo/build.gradle"
    [ -f "$repo/build.gradle.kts" ] && gradle_file="$repo/build.gradle.kts"
    if [ -f "$gradle_file" ]; then
      version="$(grep -Eo 'JavaLanguageVersion\.of\([0-9]+\)|sourceCompatibility\s*=\s*JavaVersion\.VERSION_[0-9_]+|JavaVersion\.VERSION_[0-9_]+' "$gradle_file" 2>/dev/null \
        | grep -Eo '[0-9]+' | head -1 || true)"
    fi
  fi
  if [ -z "$version" ] && [ -f "$repo/pom.xml" ]; then
    version="$(grep -E 'maven\.compiler\.(source|release)|java\.version' "$repo/pom.xml" 2>/dev/null | grep -Eo '[0-9]+' | head -1 || true)"
  fi
  if [ -z "$version" ]; then
    version="$(grep -rhE 'java-version:\s*['\''"]?[0-9]+' "$repo/.github/workflows" 2>/dev/null | grep -Eo '[0-9]+' | head -1 || true)"
  fi
  if [ -z "$version" ]; then
    version="17"
  fi
  printf '%s' "$version"
}

java_apt_package() {
  local major="${1:?JAVA_MAJOR}"
  case "$major" in
    8) printf '%s' "openjdk-8-jdk-headless" ;;
    11) printf '%s' "openjdk-11-jdk-headless" ;;
    17) printf '%s' "openjdk-17-jdk-headless" ;;
    21) printf '%s' "openjdk-21-jdk-headless" ;;
    *)
      if apt-cache show "openjdk-${major}-jdk-headless" >/dev/null 2>&1; then
        printf '%s' "openjdk-${major}-jdk-headless"
      else
        printf '%s' "default-jdk-headless"
      fi
      ;;
  esac
}

provision_java() {
  local repo="${1:?REPO_ROOT}"
  if command -v java >/dev/null 2>&1; then
    local current_major
    current_major="$(java -version 2>&1 | head -1 | grep -Eo '[0-9]+' | head -1 || true)"
    local required_major
    required_major="$(detect_java_version "$repo")"
    if [ -n "$current_major" ] && [ "$current_major" -ge "$required_major" ] 2>/dev/null; then
      echo "runtime_java=already_installed version=${current_major}"
      return 0
    fi
  fi

  local major pkg
  major="$(detect_java_version "$repo")"
  pkg="$(java_apt_package "$major")"
  echo "runtime_java_provisioning=apt package=${pkg} required_major=${major}"
  apt_retry update -qq
  DEBIAN_FRONTEND=noninteractive apt_retry install -y --no-install-recommends "$pkg" ca-certificates
  if [ -f "$repo/gradlew" ]; then
    chmod +x "$repo/gradlew"
  fi
  echo "runtime_java=installed package=${pkg} major=${major}"
}

provision_go() {
  if command -v go >/dev/null 2>&1; then
    echo "runtime_go=already_installed version=$(go version | awk '{print $3}')"
    return 0
  fi
  echo "runtime_go_provisioning=apt"
  apt_retry update -qq
  DEBIAN_FRONTEND=noninteractive apt_retry install -y --no-install-recommends golang-go
  echo "runtime_go=installed"
}

provision_node() {
  local repo="${1:?REPO_ROOT}"
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "runtime_node=already_installed version=$(node -v)"
    return 0
  fi
  echo "runtime_node_provisioning=apt"
  apt_retry update -qq
  DEBIAN_FRONTEND=noninteractive apt_retry install -y --no-install-recommends nodejs npm
  if [ -f "$repo/pnpm-lock.yaml" ] || [ -f "$repo/pnpm-workspace.yaml" ]; then
    if ! command -v pnpm >/dev/null 2>&1; then
      npm install -g pnpm
    fi
  fi
  echo "runtime_node=installed"
}

cmd_provision() {
  local work_root="${1:?WORK_ROOT}"
  local repo_root="${2:?REPO_ROOT}"
  local scan_path="${3:-$work_root/boundary_scan.json}"
  local langs=""

  if [ -f "$scan_path" ]; then
    langs="$(jq -r '.languages | join(" ")' "$scan_path" 2>/dev/null || true)"
  fi
  if [ -z "$langs" ]; then
    [ -f "$repo_root/go.mod" ] && langs="${langs} go"
    if [ -f "$repo_root/pom.xml" ] \
      || [ -f "$repo_root/build.gradle" ] \
      || [ -f "$repo_root/build.gradle.kts" ] \
      || [ -f "$repo_root/settings.gradle" ] \
      || [ -f "$repo_root/settings.gradle.kts" ] \
      || [ -f "$repo_root/gradlew" ]; then
      langs="${langs} java"
    fi
    [ -f "$repo_root/package.json" ] && langs="${langs} typescript"
  fi

  if echo "$langs" | grep -q java; then
    provision_java "$repo_root"
    mirror_note "$work_root" "runtime_java_major" "$(detect_java_version "$repo_root")"
  fi
  if echo "$langs" | grep -q go; then
    provision_go
  fi
  if echo "$langs" | grep -qE 'typescript|javascript'; then
    provision_node "$repo_root"
  fi

  mirror_note "$work_root" "runtime_deps_provisioned" "true"
  echo "runtime_deps_provisioned=true"
}

baseline_test_command() {
  local work_root="${1:?WORK_ROOT}"
  local scan_path="${2:?SCAN_JSON}"
  local override="${MONOREPO_SPLIT_BASELINE_TEST_CMD:-}"
  if [ -f "${work_root}/notes.json" ]; then
    local note_cmd
    note_cmd="$(jq -r '.baseline_test_command // empty' "${work_root}/notes.json" 2>/dev/null || true)"
    if [ -n "$note_cmd" ]; then
      override="$note_cmd"
    fi
  fi
  if [ -n "$override" ]; then
    printf '%s' "$override"
    return 0
  fi
  local cmd
  cmd="$(jq -r '
    .test_inventory as $inv |
    [
      (if $inv.java != null and $inv.java.recommended_command != "" then $inv.java.recommended_command else empty end),
      (if $inv.go != null and $inv.go.recommended_command != "" then $inv.go.recommended_command else empty end),
      (if $inv.typescript != null and $inv.typescript.recommended_command != "" then $inv.typescript.recommended_command else empty end)
    ] | .[0] // empty
  ' "$scan_path")"
  if [ -n "$cmd" ]; then
    printf '%s' "$cmd"
    return 0
  fi
  local repo_root="${3:-}"
  if [ -n "$repo_root" ] && [ -f "${repo_root}/gradlew" ]; then
    printf '%s' "./gradlew test"
    return 0
  fi
  printf ''
}

cmd_run_baseline_tests() {
  local work_root="${1:?WORK_ROOT}"
  local repo_root="${2:?REPO_ROOT}"
  local scan_path="${3:-$work_root/boundary_scan.json}"

  if [ "${MONOREPO_SPLIT_RUN_BASELINE_TESTS:-1}" != "1" ]; then
    mirror_note "$work_root" "baseline_test_status" "skipped"
    echo "baseline_test_status=skipped reason=MONOREPO_SPLIT_RUN_BASELINE_TESTS=0"
    return 0
  fi
  if [ ! -f "$scan_path" ]; then
    mirror_note "$work_root" "baseline_test_status" "skipped"
    echo "baseline_test_status=skipped reason=missing_boundary_scan"
    return 0
  fi

  local cmd
  cmd="$(baseline_test_command "$work_root" "$scan_path" "$repo_root")"
  if [ -z "$cmd" ]; then
    mirror_note "$work_root" "baseline_test_status" "skipped"
    echo "baseline_test_status=skipped reason=no_test_inventory_command"
    return 0
  fi

  local log="${work_root}/baseline_test.log"
  echo "baseline_test_command=${cmd}"
  mirror_note "$work_root" "baseline_test_command" "$cmd"

  set +e
  (cd "$repo_root" && bash -lc "$cmd") >"$log" 2>&1
  local rc=$?
  set -e

  if [ "$rc" -eq 0 ]; then
    mirror_note "$work_root" "baseline_test_status" "passed"
    mirror_note "$work_root" "baseline_test_run_evidence" "true"
    echo "baseline_test_status=passed"
    echo "baseline_test_run_evidence=true"
    tail -40 "$log" || true
    return 0
  fi

  mirror_note "$work_root" "baseline_test_status" "failed"
  mirror_note "$work_root" "baseline_test_run_evidence" "false"
  echo "baseline_test_status=failed exit_code=${rc}"
  echo "baseline_test_log_path=${log}"
  tail -60 "$log" >&2 || true
  return 0
}

case "${1:-}" in
  provision) shift; cmd_provision "$@" ;;
  baseline-tests) shift; cmd_run_baseline_tests "$@" ;;
  detect-java-version)
    shift
    detect_java_version "${1:?REPO_ROOT}"
    ;;
  *)
    echo "usage: runtime-deps-provision.sh provision|baseline-tests|detect-java-version ..." >&2
    exit 1
    ;;
esac
