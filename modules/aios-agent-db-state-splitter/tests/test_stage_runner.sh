#!/usr/bin/env bash
# Smoke tests for stage-runner script-pack guards and v2 parallel-artifact commands.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="${ROOT}/scripts/stage-runner.sh"
PY="${ROOT}/scripts/allocate_manifest.py"
WORK="$(mktemp -d)"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# Direct repo checkout invocation (developer / CI) — sibling has canonical allocate_manifest.py.
out="$(bash "$RUNNER" preflight "$WORK")"
printf '%s' "$out" | grep -q 'preflight_ok=true'

# Unembedded stdin without allocate_manifest.py in WORK_ROOT must fail.
if bash -s preflight "$WORK" 2>/dev/null << EOF
$(cat "$RUNNER")
EOF
then
  echo "FAIL: unembedded bash -s without allocate py should fail" >&2
  exit 1
fi

# Embedded invocation with verified allocate manifest succeeds.
export DBSPLIT_EMBEDDED=1
export DBSPLIT_ALLOCATE_SHA256
DBSPLIT_ALLOCATE_SHA256="$(sha256sum "$PY" | awk '{print $1}')"
mkdir -p "$WORK/scripts"
cp "$PY" "$WORK/scripts/allocate_manifest.py"
out_embed="$(bash -s preflight "$WORK" << EOF
$(cat "$RUNNER")
EOF
)"
printf '%s' "$out_embed" | grep -q 'script_pack_version='

# prepare-parallel-artifacts writes batch payloads from logical_group_manifest.json
cat >"${WORK}/logical_group_manifest.json" <<'JSON'
{
  "aws-group-001": {"cloud_hint": "aws", "resource_addresses": ["aws_vpc.main"]},
  "aws-group-002": {"cloud_hint": "aws", "resource_addresses": ["aws_s3_bucket.data"]},
  "gcp-group-003": {"cloud_hint": "gcp", "resource_addresses": ["google_storage_bucket.logs"]}
}
JSON
echo '{"address_to_identifier":{"aws_vpc.main":"vpc-1"}}' >"${WORK}/registry_mapping_report.json"

prep_out="$(bash -s prepare-parallel-artifacts "$WORK" << EOF
$(cat "$RUNNER")
EOF
)"
printf '%s' "$prep_out" | grep -q 'batch_payloads_path='
printf '%s' "$prep_out" | grep -q 'sample_group_ids_path='
[ -f "${WORK}/batch_payloads.json" ]
[ -f "${WORK}/sample_group_ids.json" ]
[ -f "${WORK}/identifier_map.json" ]
jq -e 'length == 3' "${WORK}/batch_payloads.json" >/dev/null
jq -e '.[0].resources | length >= 1' "${WORK}/batch_payloads.json" >/dev/null
jq -e '.[0].appstack_name != null' "${WORK}/batch_payloads.json" >/dev/null

# ensure_stackgen_project_note mirrors DBSPLIT_STACKGEN_PROJECT_NAME into notes.json
export DBSPLIT_STACKGEN_PROJECT_NAME="guild-demo"
stackgen_out="$(bash -s prepare-parallel-artifacts "$WORK" << EOF
$(cat "$RUNNER")
EOF
)"
printf '%s' "$stackgen_out" | grep -q 'stackgen_project_name=guild-demo'
jq -e '.stackgen_project_name == "guild-demo"' "${WORK}/notes.json" >/dev/null

# hydrate-and-plan-matrix: without group dirs, reports failures but emits roll-up sentinel
hydrate_out="$(bash -s hydrate-and-plan-matrix "$WORK" << EOF
$(cat "$RUNNER")
EOF
)" || true
printf '%s' "$hydrate_out" | grep -q 'multi_plan_zero_diff_ok:'
if command -v tofu >/dev/null 2>&1 || command -v terraform >/dev/null 2>&1; then
  printf '%s' "$hydrate_out" | grep -q 'hydrate_ok_groups='
else
  printf '%s' "$hydrate_out" | grep -q 'blocked:remote_runner_tofu_missing'
fi

# ensure_monolith_uri_from_work_root reads .work/spawn_monolith_uri (trace 8c7ea4ad guard)
mkdir -p "${WORK}/.work"
printf '%s' 'https://example.com/state.tfstate' >"${WORK}/.work/spawn_monolith_uri"
uri_out="$(bash -s ingest-and-split "$WORK" '' << EOF
$(cat "$RUNNER")
EOF
)" || true
printf '%s' "$uri_out" | grep -q 'MONOLITH_URI_from_spawn_file=true'

# emit-ingest-handoff writes compact handoff file (runner reads after large execute_series)
cat >"${WORK}/notes.json" <<'JSON'
{
  "count_reconciliation_ok": "true",
  "logical_group_count": "42",
  "logical_group_manifest_path": "/tmp/manifest.json",
  "group_state_paths": "/tmp/group_state_paths.json",
  "monolith_resource_count": "12726",
  "aggregate_group_resource_count": "12726",
  "monolith_state_local_path": "/tmp/state/terraform.tfstate",
  "script_pack_version": "20260603.33",
  "script_pack_verify_ok": "true"
}
JSON
handoff_out="$(bash -s emit-ingest-handoff "$WORK" << EOF
$(cat "$RUNNER")
EOF
)"
printf '%s' "$handoff_out" | grep -q 'count_reconciliation_ok=true'
printf '%s' "$handoff_out" | grep -q 'ingest_handoff_path='
[ -f "${WORK}/.work/ingest-handoff.txt" ]
grep -q 'logical_group_count=42' "${WORK}/.work/ingest-handoff.txt"

echo "OK: stage-runner script-pack smoke tests passed"
