#!/usr/bin/env bash
# Detect repo_archetype from boundary_scan.json signals (library vs service monorepo).
set -euo pipefail

cmd_detect() {
  local scan_path="${1:?BOUNDARY_SCAN_JSON}"

  if [ ! -f "$scan_path" ]; then
    echo "repo_archetype=ambiguous"
    echo "archetype_detect_ok=false"
    exit 0
  fi

  local result
  result="$(jq -r '
    . as $root |
    def has_deploy($r):
      (([$r.ci_deploy_units[]?.path // empty] | join(" "))
        | test("deploy|release|docker|helm|k8s|publish"; "i"));
    def has_api($r): (($r.api_surfaces // []) | length) > 0;
    ($root.modules // []) | length as $mod_count |
    ($root.ci_deploy_units // []) as $ci |
    (if $mod_count == 0 then "ambiguous"
     elif has_api($root) and (has_deploy($root) or ($ci | length) > 2) then "service_monorepo"
     elif has_api($root) then "mixed"
     elif ($ci | length) > 0 and has_deploy($root) then "service_monorepo"
     elif $mod_count >= 2 and (has_api($root) | not) and (has_deploy($root) | not) then "library_monorepo"
     else "mixed"
     end)
  ' "$scan_path")"

  if [ "$result" = "ambiguous" ]; then
    echo "repo_archetype=ambiguous"
    echo "archetype_detect_ok=false"
    exit 0
  fi

  echo "repo_archetype=${result}"
  echo "archetype_detect_ok=true"
}

case "${1:-}" in
  detect) shift; cmd_detect "$@" ;;
  *)
    echo "usage: detect-repo-archetype.sh detect BOUNDARY_SCAN_JSON" >&2
    exit 1
    ;;
esac
