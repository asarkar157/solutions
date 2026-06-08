#!/usr/bin/env bash
# change-set-preview.sh — create/describe/delete CloudFormation change set (never execute).
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-}"
SPEC="${WORK_ROOT}/requirements_spec.json"
TEMPLATE="${WORK_ROOT}/generated/template.yaml"
SUMMARY="${WORK_ROOT}/generated/change-set-preview.json"

if [[ -z "${WORK_ROOT}" ]]; then
  echo "change_set_preview_documented=false"
  echo "change_set_preview_blocked=missing_work_root"
  exit 0
fi

mkdir -p "${WORK_ROOT}/generated"

if [[ ! -f "${SPEC}" ]] || [[ ! -f "${TEMPLATE}" ]]; then
  echo "change_set_preview_documented=false"
  echo "change_set_preview_blocked=missing_template_or_spec"
  exit 0
fi

stack_name="$(jq -r '.stack_name // empty' "${SPEC}" 2>/dev/null || true)"
region="$(jq -r '.region // .aws_region // empty' "${SPEC}" 2>/dev/null || true)"
region="${region:-${AWS_REGION:-us-east-1}}"

if [[ -z "${stack_name}" ]]; then
  echo "change_set_preview_documented=false"
  echo "change_set_preview_blocked=missing_stack_name"
  exit 0
fi

aws_creds_available=false
if [[ -n "${AWS_ACCESS_KEY_ID:-}" || -n "${AWS_PROFILE:-}" ]]; then
  aws_creds_available=true
fi
if [[ -n "${AWS_ROLE_ARN:-}" && -n "${AWS_WEB_IDENTITY_TOKEN_FILE:-}" && -f "${AWS_WEB_IDENTITY_TOKEN_FILE}" ]]; then
  aws_creds_available=true
fi

if [[ "${aws_creds_available}" != "true" && "${CFN_PREVIEW_DRY_RUN:-0}" != "1" ]]; then
  jq -nc \
    --arg stack "${stack_name}" \
    --arg region "${region}" \
    '{stack_name: $stack, region: $region, mode: "dry_run", message: "AWS credentials absent — skipped live change-set preview"}' \
    > "${SUMMARY}"
  echo "change_set_preview_documented=true"
  echo "change_set_preview_mode=dry_run"
  echo "change_set_preview_path=${SUMMARY}"
  exit 0
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "change_set_preview_documented=false"
  echo "change_set_preview_blocked=aws_cli_not_installed"
  exit 0
fi

change_set_name="cfn-author-preview-$(date +%s)-$$"
create_out="$(aws cloudformation create-change-set \
  --stack-name "${stack_name}" \
  --change-set-name "${change_set_name}" \
  --template-body "file://${TEMPLATE}" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --region "${region}" 2>&1)" || {
  jq -nc --arg err "${create_out}" '{error: $err}' > "${SUMMARY}"
  echo "change_set_preview_documented=false"
  echo "change_set_preview_blocked=create_change_set_failed"
  exit 0
}

aws cloudformation wait change-set-create-complete \
  --stack-name "${stack_name}" \
  --change-set-name "${change_set_name}" \
  --region "${region}" 2>/dev/null || true

describe_out="$(aws cloudformation describe-change-set \
  --stack-name "${stack_name}" \
  --change-set-name "${change_set_name}" \
  --region "${region}" 2>/dev/null || echo '{}')"

printf '%s\n' "${describe_out}" > "${SUMMARY}"

aws cloudformation delete-change-set \
  --stack-name "${stack_name}" \
  --change-set-name "${change_set_name}" \
  --region "${region}" 2>/dev/null || true

echo "change_set_preview_documented=true"
echo "change_set_preview_path=${SUMMARY}"
