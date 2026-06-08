#!/usr/bin/env bash
# cfn-preview.sh — cfn-lint + optional change set preview markers (AWS via agent).
set -euo pipefail

TEMPLATE_PATH="${1:-}"
if [[ -z "${TEMPLATE_PATH}" || ! -f "${TEMPLATE_PATH}" ]]; then
  echo "cfn_lint_passed=false"
  echo "validate_blocked=missing_template"
  exit 1
fi

if command -v cfn-lint >/dev/null 2>&1; then
  if cfn-lint "${TEMPLATE_PATH}"; then
    echo "cfn_lint_passed=true"
  else
    echo "cfn_lint_passed=false"
    exit 0
  fi
else
  echo "cfn_lint_passed=false"
  echo "validate_blocked=skipped_no_cfn_lint"
  exit 0
fi

echo "validate_template_passed=pending_aws_agent"
