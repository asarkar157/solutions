#!/usr/bin/env bash
# change-set-preview_test.sh — dry-run preview when AWS credentials absent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(mktemp -d)"
trap 'rm -rf "${WORK_ROOT}"' EXIT

mkdir -p "${WORK_ROOT}/generated"
printf '{"stack_name":"staging-data","region":"us-east-1","intent":"test"}' > "${WORK_ROOT}/requirements_spec.json"
printf 'Resources:\n  Bucket:\n    Type: AWS::S3::Bucket\n' > "${WORK_ROOT}/generated/template.yaml"

export WORK_ROOT
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_PROFILE AWS_SESSION_TOKEN || true
out="$(bash "${ROOT}/change-set-preview.sh")"
printf '%s\n' "${out}"

echo "${out}" | grep -q 'change_set_preview_documented=true' || { echo "FAIL: expected dry-run documented" >&2; exit 1; }
echo "${out}" | grep -q 'change_set_preview_mode=dry_run' || { echo "FAIL: expected dry_run mode" >&2; exit 1; }

# IRSA / web-identity credentials must not force dry_run.
WORK_ROOT_IRSA="$(mktemp -d)"
trap 'rm -rf "${WORK_ROOT}" "${WORK_ROOT_IRSA}"' EXIT
mkdir -p "${WORK_ROOT_IRSA}/generated"
cp "${WORK_ROOT}/requirements_spec.json" "${WORK_ROOT_IRSA}/requirements_spec.json"
cp "${WORK_ROOT}/generated/template.yaml" "${WORK_ROOT_IRSA}/generated/template.yaml"
TOKEN_FILE="$(mktemp)"
printf 'fake-token' > "${TOKEN_FILE}"
export WORK_ROOT="${WORK_ROOT_IRSA}"
export AWS_ROLE_ARN="arn:aws:iam::123456789012:role/test"
export AWS_WEB_IDENTITY_TOKEN_FILE="${TOKEN_FILE}"
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_PROFILE AWS_SESSION_TOKEN || true
irsa_out="$(bash "${ROOT}/change-set-preview.sh")"
printf '%s\n' "${irsa_out}"
echo "${irsa_out}" | grep -q 'change_set_preview_mode=dry_run' && {
  echo "FAIL: IRSA creds must not force dry_run" >&2
  exit 1
}

echo "OK: change-set-preview dry run"
