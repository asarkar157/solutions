#!/usr/bin/env bash
# Build coupling-matrix.json from boundary_scan.json module graphs (language-agnostic).
set -euo pipefail

cmd_build() {
  local scan_path="${1:?BOUNDARY_SCAN_JSON}"
  local out_path="${2:-}"

  if [ ! -f "$scan_path" ]; then
    echo "coupling_matrix_error=missing_scan" >&2
    exit 1
  fi

  if [ -z "$out_path" ]; then
    out_path="$(dirname "$scan_path")/coupling-matrix.json"
  fi

  jq '
    .modules as $mods |
    ($mods | map(.path)) as $paths |
    ($mods | map({
      key: .path,
      value: ((.depends_on // []) | map(select(. as $d | $paths | index($d))))
    }) | from_entries) as $dep_map |
    ($mods | map(
      .path as $p |
      . + {
        inbound_edges: ([$mods[] | select((.depends_on // []) | index($p))] | length),
        outbound_edges: ((.depends_on // []) | length)
      }
    )) as $enriched |
    def hub_excluded($p):
      $p | test("-(test|bom|all)$|_test$|^test-"; "i");
    ($enriched
      | map(select(.path | hub_excluded(.) | not))
      | sort_by(-.inbound_edges)
      | .[0].path // "") as $hub_candidate |
    (if $hub_candidate != "" then $hub_candidate
     else ($enriched | sort_by(-.inbound_edges) | .[0].path // "")
     end) as $hub |
    ($enriched | [.[].path]) as $all_paths |
    ($enriched | reduce .[] as $m (
      [];
      . + [($m.depends_on // []) | map(select(. as $d | $all_paths | index($d) | not)) | .[]] | unique
    ) | unique) as $roots |
    ($enriched | [.[].path] | length) as $count |
    if $count == 0 then
      { modules: [], hub_module: "", extraction_order: [], module_count: 0 }
    else
      {
        modules: $enriched,
        hub_module: $hub,
        extraction_order: (
          [$roots[] as $r | $r] +
          [$enriched | sort_by(.inbound_edges) | .[].path | select(. as $x | $roots | index($x) | not)]
        | unique),
        module_count: $count,
        max_inbound: ($enriched | map(.inbound_edges) | max // 0)
      }
    end
  ' "$scan_path" >"$out_path"

  echo "coupling_matrix_path=${out_path}"
  echo "coupling_matrix_ok=true"
}

case "${1:-}" in
  build) shift; cmd_build "$@" ;;
  *)
    echo "usage: build-coupling-matrix.sh build BOUNDARY_SCAN_JSON [OUT_PATH]" >&2
    exit 1
    ;;
esac
