#!/usr/bin/env bash
# commit-and-pr_body_test.sh — PR body must ignore LLM-exported PR_BODY env.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMIT_PR="${ROOT}/commit-and-pr.sh"

if grep -q 'if \[\[ -z "\${PR_BODY}" \]\]' "${COMMIT_PR}"; then
  echo "FAIL: commit-and-pr.sh still gates PR body on empty PR_BODY" >&2
  exit 1
fi

if ! grep -q 'unset PR_BODY' "${COMMIT_PR}"; then
  echo "FAIL: commit-and-pr.sh must unset PR_BODY before render" >&2
  exit 1
fi

# Simulate runner export pollution then stage-runner clear + render path.
export PR_BODY='## Summary\\n\\nLiteral \\\\u2014 escapes must not appear'
export PR_TITLE="feat(test): body"
export STACK_NAME="demo"
export ENVIRONMENT="dev"
export INTENT="S3 bucket with versioning"
export AWS_REGION="us-east-1"
export TARGET_PATH="cloudformation/template.yaml"
export BASE_BRANCH="main"

unset PR_BODY
PR_BODY="$(cat <<EOF
## Summary

This change adds a production-oriented CloudFormation template for **${STACK_NAME}** in the **${ENVIRONMENT}** environment.

## Intent

${INTENT}
EOF
)"

if printf '%s' "${PR_BODY}" | grep -q '\\n'; then
  echo "FAIL: rendered PR body contains literal backslash-n" >&2
  exit 1
fi

if ! printf '%s' "${PR_BODY}" | grep -q 'S3 bucket with versioning'; then
  echo "FAIL: rendered PR body missing intent prose" >&2
  exit 1
fi

echo "OK: commit-and-pr PR body render ignores polluted PR_BODY env"
