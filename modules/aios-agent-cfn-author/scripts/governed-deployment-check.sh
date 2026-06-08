#!/usr/bin/env bash
# governed-deployment-check.sh — org deployment prerequisites before opening PR.
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-}"
SPEC="${WORK_ROOT}/requirements_spec.json"

if [[ ! -f "${SPEC}" ]] || ! command -v jq >/dev/null 2>&1; then
  echo "governed_deployment_blocked=true"
  echo "governed_deployment_blocker=missing_requirements_spec"
  exit 1
fi

stack_name="$(jq -r '.stack_name // empty' "${SPEC}")"
environment="$(jq -r '.environment // empty' "${SPEC}")"
intent="$(jq -r '.intent // empty' "${SPEC}")"

if [[ -z "${stack_name}" ]]; then
  echo "governed_deployment_blocked=true"
  echo "governed_deployment_blocker=missing_stack_name"
  exit 1
fi

if [[ -z "${intent}" ]]; then
  echo "governed_deployment_blocked=true"
  echo "governed_deployment_blocker=missing_intent"
  exit 1
fi

if [[ "${environment}" == "prod" || "${environment}" == "production" ]]; then
  confirm="$(jq -r '.confirm_deploy // "false"' "${SPEC}")"
  if [[ "${confirm}" != "true" ]]; then
    echo "governed_deployment_blocked=true"
    echo "governed_deployment_blocker=prod_requires_confirm_deploy"
    exit 1
  fi
fi

echo "governed_deployment_ready=true"
