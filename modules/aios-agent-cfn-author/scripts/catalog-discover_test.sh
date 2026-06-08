#!/usr/bin/env bash
# catalog-discover_test.sh — keyword matching without live GitHub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(mktemp -d)"
FIXTURE="${WORK_ROOT}/catalog-fixture/cloudformation/catalog"
trap 'rm -rf "${WORK_ROOT}"' EXIT

mkdir -p "${FIXTURE}/storage" "${FIXTURE}/data"
printf 'Resources:\n  Bucket:\n    Type: AWS::S3::Bucket\n' > "${FIXTURE}/storage/s3-versioned.yaml"
printf 'Resources:\n  Db:\n    Type: AWS::RDS::DBInstance\n' > "${FIXTURE}/data/rds-private.yaml"

printf '{"intent":"S3 bucket with versioning","stack_name":"staging-data"}' > "${WORK_ROOT}/requirements_spec.json"

export WORK_ROOT CATALOG_DISCOVER_FIXTURE_DIR="${FIXTURE}" CFN_AUTHOR_CATALOG_PATH="cloudformation/catalog/"
out="$(bash "${ROOT}/catalog-discover.sh")"
printf '%s\n' "${out}"

count="$(jq 'length' "${WORK_ROOT}/generated/catalog_candidates.json")"
[[ "${count}" -ge 1 ]] || { echo "FAIL: expected catalog candidates" >&2; exit 1; }
top="$(jq -r '.[0].path' "${WORK_ROOT}/generated/catalog_candidates.json")"
[[ "${top}" == *"s3"* ]] || { echo "FAIL: expected s3 candidate first, got ${top}" >&2; exit 1; }

echo "OK: catalog-discover keyword match"
