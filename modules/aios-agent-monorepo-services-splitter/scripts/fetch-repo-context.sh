#!/usr/bin/env bash
# Fetch bounded repo context for LLM enrichment (README, CONTRIBUTING, module roots).
set -euo pipefail

MAX_BYTES=32768

truncate_file() {
  local path="${1:?PATH}"
  local max="${2:-8192}"
  if [ ! -f "$path" ]; then
    return 0
  fi
  head -c "$max" "$path"
}

cmd_fetch() {
  local work_root="${1:?WORK_ROOT}"
  local repo_dir="${2:?REPO_DIR}"
  local out="${work_root}/repo_context.json"

  if [ ! -d "$repo_dir" ]; then
    echo "repo_context_ok=false"
    echo "repo_context_error=missing_repo"
    exit 1
  fi

  local readme="" contributing="" gomod="" settings=""
  readme="$(truncate_file "$repo_dir/README.md" 12000)"
  contributing="$(truncate_file "$repo_dir/CONTRIBUTING.md" 4000)"
  if [ -f "$repo_dir/go.mod" ]; then
    gomod="$(head -30 "$repo_dir/go.mod")"
  fi
  if [ -f "$repo_dir/settings.gradle.kts" ]; then
    settings="$(head -40 "$repo_dir/settings.gradle.kts")"
  elif [ -f "$repo_dir/settings.gradle" ]; then
    settings="$(head -40 "$repo_dir/settings.gradle")"
  fi

  jq -n \
    --arg readme "$readme" \
    --arg contributing "$contributing" \
    --arg gomod "$gomod" \
    --arg settings "$settings" \
    '{
      readme_excerpt: $readme,
      contributing_excerpt: $contributing,
      go_mod_header: $gomod,
      gradle_settings_header: $settings
    }' >"$out"

  echo "repo_context_path=${out}"
  echo "repo_context_ok=true"
}

case "${1:-}" in
  fetch) shift; cmd_fetch "$@" ;;
  *)
    echo "usage: fetch-repo-context.sh fetch WORK_ROOT REPO_DIR" >&2
    exit 1
    ;;
esac
