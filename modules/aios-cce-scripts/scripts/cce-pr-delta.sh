#!/usr/bin/env bash
# PR / branch entitlement delta for change-control and pre-deploy-iam-review.
# Usage: cce-pr-delta.sh delta REPO_DIR BASE_REF HEAD_REF [WORK_ROOT]
# Writes ${WORK_ROOT}/cce_pr_delta.json, compact summaries, optional PR comment markdown.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=cce-common.sh
. "${SCRIPT_DIR}/cce-common.sh"
CCE_SCAN="${SCRIPT_DIR}/cce-scan.sh"

CCE_PR_DELTA_TOP_N="${CCE_PR_DELTA_TOP_N:-5}"
CCE_PR_COMMENT_TOP_N="${CCE_PR_COMMENT_TOP_N:-10}"

emit_pr_delta_artifacts() {
  local work_root="${1:?WORK_ROOT}"
  local delta_json="${2:?DELTA_JSON}"

  local count status
  count="$(jq -r '.new_entitlement_count // (.new_entitlements | length) // 0' "$delta_json" 2>/dev/null || echo 0)"
  status="$(jq -r '.scan_status // "unknown"' "$delta_json" 2>/dev/null || echo unknown)"

  jq \
    --argjson top_n "$CCE_PR_DELTA_TOP_N" \
    '{top_new: (.new_entitlements[0:$top_n] | map({
      provider, resource, operation, method, file, line
    }))}' "$delta_json" >"${work_root}/cce_new_entitlements_summary.json"

  jq \
    --argjson top_n "$CCE_PR_COMMENT_TOP_N" \
    --argjson total "$count" '
    def row($e):
      "| \($e.provider // "-") | \($e.resource // "-") | \($e.operation // "-") | \($e.file // "-") | \($e.line // "-") |";
    "# Pre-deploy IAM review (CCE)\n\n\($total) new cloud API call site(s) vs base branch.\n\n| Provider | Resource | Operation | File | Line |\n| --- | --- | --- | --- | --- |",
    (.new_entitlements[0:$top_n] | map(row(.)) | join("\n")),
    (if ($total > $top_n) then "\n\n_Showing top \($top_n); see cce_pr_delta.json for full list._" else "" end)
    ' "$delta_json" >"${work_root}/cce_pr_comment.md" 2>/dev/null || true

  echo "cce_pr_delta_path=${delta_json}"
  echo "cce_new_entitlement_count=${count}"
  echo "cce_scan_status=${status}"
  echo "cce_new_entitlements_summary_path=${work_root}/cce_new_entitlements_summary.json"
  if [ -f "${work_root}/cce_pr_comment.md" ]; then
    echo "cce_pr_comment_path=${work_root}/cce_pr_comment.md"
  fi
}

run_delta() {
  local repo_dir="${1:?REPO_DIR}"
  local base_ref="${2:?BASE_REF}"
  local head_ref="${3:?HEAD_REF}"
  local work_root="${4:-${WORK_ROOT:-$(mktemp -d)}}"

  mkdir -p "$work_root"
  local out="${work_root}/cce_pr_delta.json"

  if cce_skip_scan; then
    jq -n \
      --arg base "$base_ref" --arg head "$head_ref" \
      '{scan_status: "skipped", reason: "SKIP_CCE", new_entitlements: [], removed_entitlements: [], new_entitlement_count: 0}' | tee "$out" >/dev/null
    emit_pr_delta_artifacts "$work_root" "$out"
    return 0
  fi

  if [ ! -d "${repo_dir}/.git" ]; then
    jq -n \
      --arg base "$base_ref" --arg head "$head_ref" \
      '{scan_status: "failed", reason: "not_a_git_repo", new_entitlements: [], removed_entitlements: [], new_entitlement_count: 0}' | tee "$out" >/dev/null
    emit_pr_delta_artifacts "$work_root" "$out"
    return 0
  fi

  local tmp_base tmp_head
  tmp_base="$(mktemp -d)"
  tmp_head="$(mktemp -d)"
  trap 'rm -rf "$tmp_base" "$tmp_head"' EXIT

  git -C "$repo_dir" archive "$base_ref" | tar -x -C "$tmp_base"
  git -C "$repo_dir" archive "$head_ref" | tar -x -C "$tmp_head"

  local base_json head_json
  base_json="$(mktemp)"
  head_json="$(mktemp)"
  CCE_USE_CASE="${CCE_USE_CASE:-change-control}" \
    bash "$CCE_SCAN" scan "$tmp_base" "$base_json" >/dev/null
  CCE_USE_CASE="${CCE_USE_CASE:-change-control}" \
    bash "$CCE_SCAN" scan "$tmp_head" "$head_json" >/dev/null

  jq -s \
    --arg base "$base_ref" \
    --arg head "$head_ref" \
    --slurpfile base "$base_json" \
    --slurpfile head "$head_json" '
    ($base[0].entitlements // []) as $b |
    ($head[0].entitlements // []) as $h |
    def ent_key: [.provider, .resource, .operation, .method] | map(. // "") | join("|");
    ($b | map(ent_key)) as $bk |
    ($h | map(ent_key)) as $hk |
    ($h | map(select((ent_key) as $k | ($bk | index($k) | not)))) as $new_ents |
    ($b | map(select((ent_key) as $k | ($hk | index($k) | not)))) as $removed_ents |
    {
      scan_status: "ok",
      base_ref: $base,
      head_ref: $head,
      base_summary: $base[0].summary,
      head_summary: $head[0].summary,
      new_entitlements: $new_ents,
      removed_entitlements: $removed_ents,
      new_entitlement_count: ($new_ents | length)
    }
  ' <<<"[]" | tee "$out" >/dev/null

  emit_pr_delta_artifacts "$work_root" "$out"
}

case "${1:-}" in
  delta)
    shift
    run_delta "$@"
    ;;
  *)
    echo "usage: cce-pr-delta.sh delta REPO_DIR BASE_REF HEAD_REF [WORK_ROOT]" >&2
    exit 1
    ;;
esac
