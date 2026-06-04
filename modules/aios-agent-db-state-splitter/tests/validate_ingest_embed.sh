#!/usr/bin/env bash
# Validates ingest bootstrap script: shell syntax, base64 round-trip, secret JSON field export.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${ROOT}/templates/ingest-execute-series-embedded.sh.tftpl"
WORK="${ROOT}/.test-work-ingest-embed"

cleanup() {
  rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$WORK"

helpers_rendered="$WORK/dbsplit-script-pack-env.sh"
sed \
  -e 's/\${script_pack_version}/20260604.7/g' \
  -e 's/\${script_pack_allocate_sha256}/0000000000000000000000000000000000000000000000000000000000000000/g' \
  -e 's/\${script_pack_runner_sha256}/0000000000000000000000000000000000000000000000000000000000000000/g' \
  -e 's/\$\${/\${/g' \
  "${ROOT}/templates/dbsplit-script-pack-env.sh.tftpl" >"$helpers_rendered"

rendered="$WORK/ingest-execute-series.sh"
sed \
  -e 's/\${script_pack_git_ref}/main/g' \
  -e 's/\${script_pack_version}/20260604.7/g' \
  -e 's/\${script_pack_allocate_sha256}/0000000000000000000000000000000000000000000000000000000000000000/g' \
  -e 's/\${script_pack_runner_sha256}/0000000000000000000000000000000000000000000000000000000000000000/g' \
  -e 's/\${default_grouping_strategy}/tag_seeded_connectivity/g' \
  -e 's/\${default_max_resources_per_appstack}/200/g' \
  -e 's/\${runner_work_home}/\/home\/runner/g' \
  -e 's/\$\${WORKFLOW_RUN_ID}/test-wf-run/g' \
  -e 's/{{workflow_run_id}}/test-wf-run/g' \
  -e 's/\$\${/\${/g' \
  "$TEMPLATE" >"$WORK/ingest-template-intermediate.sh"

awk -v helpers="$helpers_rendered" '
  /\$\{dbsplit_script_pack_env_helpers\}/ {
    while ((getline line < helpers) > 0) print line
    close(helpers)
    next
  }
  { print }
' "$WORK/ingest-template-intermediate.sh" >"$rendered"

if ! bash -n "$rendered"; then
  echo "FAIL: ingest bootstrap body failed bash -n" >&2
  exit 1
fi

if grep -q 'DBSPLIT_INGEST_EXECUTE' "$rendered"; then
  echo "FAIL: ingest bootstrap must not use outer heredoc wrapper" >&2
  exit 1
fi

if ! grep -q 'dbsplit_load_script_pack_env' "$rendered"; then
  echo "FAIL: ingest bootstrap must load script pack from runner env JSON" >&2
  exit 1
fi

if grep -q 'script_pack_allocate_b64' "$rendered"; then
  echo "FAIL: ingest bootstrap must not inline terraform script_pack_*_b64 (use runner env sync)" >&2
  exit 1
fi

if ! grep -q 'DBSPLIT_INGEST_BOOTSTRAP_B64' "$helpers_rendered"; then
  echo "FAIL: dbsplit-script-pack-env must export DBSPLIT_INGEST_BOOTSTRAP_B64" >&2
  exit 1
fi

b64="$(base64 <"$rendered" | tr -d '\n')"
b64_len="${#b64}"
if [ $((b64_len % 4)) -ne 0 ]; then
  echo "FAIL: base64 length ${b64_len} is not a multiple of 4" >&2
  exit 1
fi

roundtrip="$WORK/roundtrip.sh"
if ! base64 -d <<<"$b64" >"$roundtrip"; then
  echo "FAIL: base64 decode round-trip failed" >&2
  exit 1
fi

if ! cmp -s "$rendered" "$roundtrip"; then
  echo "FAIL: base64 round-trip content mismatch" >&2
  exit 1
fi

echo "OK: ingest bootstrap bash -n + base64 round-trip (len=${b64_len}, stored in DBSPLIT_INGEST_BOOTSTRAP_B64)"
