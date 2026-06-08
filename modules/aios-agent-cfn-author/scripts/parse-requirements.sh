#!/usr/bin/env bash
# parse-requirements.sh — normalize webhook JSON or prose into requirements_spec.json.
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO="${REPO_FULL_NAME:-}"
DEFAULT_WORKSPACE="${WORKSPACE_ID:-${CFN_AUTHOR_DEFAULT_WORKSPACE:-}}"
DEFAULT_BRANCH="${BASE_BRANCH:-main}"
TEMPLATE_PREFIX="${TEMPLATE_PREFIX:-cloudformation/}"

if [[ -z "${WORK_ROOT}" ]]; then
  echo "requirements_blocked=true"
  echo "requirements_parsed=false"
  echo "requirements_blocker=missing_work_root"
  exit 1
fi

mkdir -p "${WORK_ROOT}"
INPUT_FILE="${WORK_ROOT}/stage_input.json"
RAW_FILE="${WORK_ROOT}/stage_input.raw"

if [[ -n "${STAGE_INPUT_FILE:-}" && -f "${STAGE_INPUT_FILE}" ]]; then
  if [[ "${STAGE_INPUT_FILE}" != "${RAW_FILE}" ]]; then
    cp "${STAGE_INPUT_FILE}" "${RAW_FILE}"
  fi
elif [[ -f "${RAW_FILE}" ]]; then
  :
elif [[ -f "${INPUT_FILE}" ]]; then
  cp "${INPUT_FILE}" "${RAW_FILE}"
elif [[ -n "${STAGE_INPUT:-}" ]]; then
  printf '%s' "${STAGE_INPUT}" > "${RAW_FILE}"
else
  echo "requirements_blocked=true"
  echo "requirements_parsed=false"
  echo "requirements_blocker=missing_stage_input"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "requirements_blocked=true"
  echo "requirements_parsed=false"
  echo "requirements_blocker=missing_jq"
  exit 1
fi

intent=""
input_parsed_as_json=true
if jq -e . "${RAW_FILE}" >/dev/null 2>&1; then
  cp "${RAW_FILE}" "${INPUT_FILE}"
  intent="$(jq -r '.intent // .request // .description // empty' "${INPUT_FILE}")"
else
  input_parsed_as_json=false
  intent="$(tr -d '\0' < "${RAW_FILE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  jq -n \
    --arg intent "${intent}" \
    --arg workspace_id "${DEFAULT_WORKSPACE}" \
    --arg repo "${DEFAULT_REPO}" \
    --arg branch "${DEFAULT_BRANCH}" \
    --arg path_prefix "${TEMPLATE_PREFIX}" \
    '{intent: $intent, workspace_id: ($workspace_id|select(. != "")), github_repo_override: ($repo|select(. != "")), requirements_source: "prose"}' \
    > "${INPUT_FILE}"
fi

jq \
  --arg default_ws "${DEFAULT_WORKSPACE}" \
  --arg default_repo "${DEFAULT_REPO}" \
  --arg default_branch "${DEFAULT_BRANCH}" \
  --arg path_prefix "${TEMPLATE_PREFIX}" \
  '
  . as $in
  | {
      intent: ($in.intent // $in.request // $in.description // ""),
      stack_name: ($in.stack_name // ""),
      environment: ($in.environment // ""),
      template_file_name: ($in.template_file_name // $in.template_output_path // ""),
      catalog_repo: ($in.catalog_repo // ""),
      github_repo_override: ($in.github_repo_override // $in.repository // $default_repo // ""),
      workspace_id: ($in.workspace_id // $default_ws // ""),
      correlation_id: ($in.correlation_id // ""),
      confirm_deploy: ($in.confirm_deploy // ""),
      region: ($in.region // $in.aws_region // ""),
      base_branch: ($in.base_branch // $default_branch // ""),
      path_prefix: ($in.path_prefix // $path_prefix // ""),
      target_rps: ($in.target_rps // ""),
      sla_availability: ($in.sla_availability // ""),
      p99_latency_ms: ($in.p99_latency_ms // ""),
      workload_class: ($in.workload_class // ""),
      requirements_source: ($in.requirements_source // "json")
    }
  | with_entries(select(.value != "" and .value != null))
  ' "${INPUT_FILE}" > "${WORK_ROOT}/requirements_spec.json"

bash "${SCRIPT_DIR}/nfr-enrichment.sh" "${WORK_ROOT}/requirements_spec.json" > "${WORK_ROOT}/requirements_spec.enriched.json"
mv "${WORK_ROOT}/requirements_spec.enriched.json" "${WORK_ROOT}/requirements_spec.json"

# Normalize confirm_deploy to lowercase true/false for downstream gates.
if jq -e '.confirm_deploy' "${WORK_ROOT}/requirements_spec.json" >/dev/null 2>&1; then
  normalized_confirm="$(jq -r '
    .confirm_deploy
    | if type == "boolean" then (if . then "true" else "false" end)
      elif type == "string" then (ascii_downcase | if . == "true" or . == "1" or . == "yes" then "true" else "false" end)
      else "false" end
  ' "${WORK_ROOT}/requirements_spec.json")"
  jq --arg cd "${normalized_confirm}" '. + {confirm_deploy: $cd}' "${WORK_ROOT}/requirements_spec.json" \
    > "${WORK_ROOT}/requirements_spec.normalized.json"
  mv "${WORK_ROOT}/requirements_spec.normalized.json" "${WORK_ROOT}/requirements_spec.json"
else
  jq '. + {confirm_deploy: "false"}' "${WORK_ROOT}/requirements_spec.json" \
    > "${WORK_ROOT}/requirements_spec.normalized.json"
  mv "${WORK_ROOT}/requirements_spec.normalized.json" "${WORK_ROOT}/requirements_spec.json"
fi

intent="$(jq -r '.intent // empty' "${WORK_ROOT}/requirements_spec.json")"
correlation_id="$(jq -r '.correlation_id // empty' "${WORK_ROOT}/requirements_spec.json")"
confirm_deploy="$(jq -r '.confirm_deploy // "false"' "${WORK_ROOT}/requirements_spec.json")"
stack_name="$(jq -r '.stack_name // empty' "${WORK_ROOT}/requirements_spec.json")"
target_rps="$(jq -r '.target_rps // empty' "${WORK_ROOT}/requirements_spec.json")"
workload_class="$(jq -r '.workload_class // empty' "${WORK_ROOT}/requirements_spec.json")"
requirements_source="$(jq -r '.requirements_source // "json"' "${WORK_ROOT}/requirements_spec.json")"
ci_pipeline="$(jq -r '.ci_pipeline // empty' "${WORK_ROOT}/requirements_spec.json")"
caller="$(jq -r '.caller // empty' "${WORK_ROOT}/requirements_spec.json")"

orchestration_source="webhook"
if [[ "${input_parsed_as_json}" != "true" || "${requirements_source}" == "prose" ]]; then
  orchestration_source="chat"
elif [[ -n "${ci_pipeline}" ]]; then
  orchestration_source="cicd"
elif [[ -n "${caller}" ]]; then
  orchestration_source="external_agent"
fi

if [[ -z "${intent}" ]]; then
  echo "requirements_blocked=true"
  echo "requirements_parsed=false"
  echo "requirements_blocker=missing_intent"
  exit 0
fi

echo "requirements_parsed=true"
echo "requirements_blocked=false"
echo "orchestration_source=${orchestration_source}"
if [[ -n "${correlation_id}" ]]; then
  echo "correlation_id=${correlation_id}"
fi
if [[ -n "${stack_name}" ]]; then
  echo "stack_name=${stack_name}"
fi
if [[ -n "${target_rps}" ]]; then
  echo "target_rps=${target_rps}"
fi
if [[ -n "${workload_class}" ]]; then
  echo "workload_class=${workload_class}"
fi
echo "confirm_deploy=${confirm_deploy}"
echo "requirements_spec_path=${WORK_ROOT}/requirements_spec.json"

export WORK_ROOT REPO_FULL_NAME="${DEFAULT_REPO}" CATALOG_REPO="$(jq -r '.catalog_repo // empty' "${WORK_ROOT}/requirements_spec.json")" CFN_AUTHOR_CATALOG_PATH="${CFN_AUTHOR_CATALOG_PATH:-${TEMPLATE_PREFIX}catalog/}"
bash "${SCRIPT_DIR}/catalog-discover.sh" >/dev/null 2>&1 || true
