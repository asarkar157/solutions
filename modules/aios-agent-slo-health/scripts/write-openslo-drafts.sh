#!/usr/bin/env bash
# write-openslo-drafts.sh — render OpenSLO YAML from slo_proposals_validated.json.
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-}"
INPUT_JSON="${WORK_ROOT}/slo_proposals_validated.json"
DRAFT_ROOT="${WORK_ROOT}/openslo-drafts"
BATCH_IDS="${BATCH_IDS:-}"

# yaml_block_lines renders a YAML literal block scalar body with the given indent prefix.
yaml_block_lines() {
  local text="$1"
  local indent="$2"
  if [[ -z "${text}" ]]; then
    printf '%s\n' "${indent}"
    return
  fi
  while IFS= read -r line || [[ -n "${line}" ]]; do
    printf '%s%s\n' "${indent}" "${line}"
  done <<< "${text}"
}

if [[ -z "${WORK_ROOT}" ]]; then
  echo "draft_blocker=missing_work_root"
  exit 1
fi

if [[ ! -f "${INPUT_JSON}" ]]; then
  echo "draft_blocker=missing_validated_json"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "draft_blocker=missing_jq"
  exit 1
fi

normalized="$(mktemp)"
if jq -e '.proposals | type == "array"' "${INPUT_JSON}" >/dev/null 2>&1; then
  jq '.proposals' "${INPUT_JSON}" > "${normalized}"
elif jq -e 'type == "array"' "${INPUT_JSON}" >/dev/null 2>&1; then
  cp "${INPUT_JSON}" "${normalized}"
else
  echo "draft_blocker=invalid_json_shape"
  exit 1
fi

base_filter='select((.validation_status // "valid") == "valid" or (.validation_status // "") == "passed")'

if [[ -n "${BATCH_IDS}" ]]; then
  ids_json="$(printf '%s' "${BATCH_IDS}" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))')"
  jq -c --argjson ids "${ids_json}" ".[] | ${base_filter} | select((.id // .name) as \$id | \$ids | index(\$id) != null)" "${normalized}" > "${normalized}.items"
else
  jq -c ".[] | ${base_filter}" "${normalized}" > "${normalized}.items"
fi

if [[ ! -s "${normalized}.items" ]]; then
  echo "draft_blocker=no_valid_proposals"
  exit 1
fi

written=0
manifest_items="[]"

while IFS= read -r item; do
  [[ -z "${item}" ]] && continue

  service="$(echo "${item}" | jq -r '.service // .metadata.labels.service // "unknown"')"
  name="$(echo "${item}" | jq -r '.name // .id // .metadata.name // empty')"
  target="$(echo "${item}" | jq -r '.target // .objectives[0].target // .availability_target // "0.999"')"
  good_q="$(echo "${item}" | jq -r '.good_promql // .good_query // .indicator.spec.ratioMetric.good.metricSource.spec.query // empty')"
  total_q="$(echo "${item}" | jq -r '.total_promql // .total_query // .indicator.spec.ratioMetric.total.metricSource.spec.query // empty')"
  proposed_path="$(echo "${item}" | jq -r '.proposed_path // empty')"
  description="$(echo "${item}" | jq -r '.description // .spec.description // ("SLO for " + (.service // "service"))')"
  signal_type="$(echo "${item}" | jq -r '.signal_type // "availability"')"

  if [[ -z "${name}" || -z "${good_q}" || -z "${total_q}" ]]; then
    continue
  fi

  if [[ -n "${proposed_path}" && "${proposed_path}" != "null" ]]; then
    rel="${proposed_path#openslo/}"
    rel="${rel#${OPENSLO_PATH_PREFIX:-openslo/}}"
    dest="${DRAFT_ROOT}/${rel}"
  else
    fname="${signal_type}.yaml"
    if [[ "${signal_type}" == "latency" ]]; then
      fname="latency-p99.yaml"
    fi
    dest="${DRAFT_ROOT}/slos/${service}/${fname}"
  fi

  mkdir -p "$(dirname "${dest}")"

  display_name="$(echo "${item}" | jq -r '.displayName // .metadata.displayName // empty')"
  if [[ -z "${display_name}" || "${display_name}" == "null" ]]; then
    display_name="${service} — ${signal_type} SLO"
  fi

  cat > "${dest}" <<EOF
apiVersion: openslo/v1
kind: SLO
metadata:
  name: ${name}
  displayName: |-
$(yaml_block_lines "${display_name}" "    ")
  labels:
    service: ${service}
spec:
  description: |-
$(yaml_block_lines "${description}" "    ")
  service: ${service}
  budgetingMethod: Occurrences
  timeWindow:
    - duration: 30d
      isRolling: true
  indicator:
    metadata:
      name: ${name}
    spec:
      ratioMetric:
        counter: true
        good:
          metricSource:
            type: Prometheus
            spec:
              query: ${good_q}
        total:
          metricSource:
            type: Prometheus
            spec:
              query: ${total_q}
  objectives:
    - displayName: ${target} target
      target: ${target}
EOF

  written=$((written + 1))
  manifest_items="$(echo "${manifest_items}" | jq -c --arg p "${dest#${DRAFT_ROOT}/}" --arg s "${service}" --arg n "${name}" '. + [{path: $p, service: $s, name: $n}]')"
done < "${normalized}.items"

rm -f "${normalized}" "${normalized}.items"

if [[ "${written}" -eq 0 ]]; then
  echo "draft_blocker=no_files_written"
  exit 1
fi

printf '%s\n' "${manifest_items}" | jq '{files: .}' > "${WORK_ROOT}/draft_files.json"
echo "draft_files_count=${written}"
echo "draft_manifest=${WORK_ROOT}/draft_files.json"
exit 0
