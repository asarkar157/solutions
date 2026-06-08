#!/usr/bin/env bash
# architecture-lint.sh — deterministic NFR + template architecture checks (post-synthesis).
set -euo pipefail

WORK_ROOT="${WORK_ROOT:-}"
TEMPLATE="${WORK_ROOT}/generated/template.yaml"
SPEC="${WORK_ROOT}/requirements_spec.json"
OUT="${WORK_ROOT}/generated/architecture-findings.json"
FEDRAMP_PROFILE="${FEDRAMP_PROFILE:-moderate}"
HIGH_RPS_THRESHOLD="${CFN_AUTHOR_HIGH_RPS_THRESHOLD:-100000}"

mkdir -p "${WORK_ROOT}/generated"

if [[ ! -f "${TEMPLATE}" ]]; then
  echo "architecture_lint_passed=false"
  echo "architecture_summary=FAIL"
  echo "architecture_blocked=true"
  echo "architecture_blocker=missing_generated_template"
  exit 1
fi

findings=()
add_finding() {
  local id="$1" severity="$2" message="$3" remediation="${4:-}"
  findings+=("$(jq -nc --arg id "${id}" --arg sev "${severity}" --arg msg "${message}" --arg hint "${remediation}" \
    '{id: $id, severity: $sev, message: $msg, remediation_hint: $hint}')")
}

target_rps=""
workload_class=""
if [[ -f "${SPEC}" ]] && command -v jq >/dev/null 2>&1; then
  target_rps="$(jq -r '.target_rps // empty' "${SPEC}")"
  workload_class="$(jq -r '.workload_class // empty' "${SPEC}")"
fi

template_text="$(cat "${TEMPLATE}")"

if grep -q 'EC2SpotFleetRequestAverageCPUUtilization' "${TEMPLATE}"; then
  if grep -q 'AWS::AutoScaling::AutoScalingGroup' "${TEMPLATE}" && ! grep -q 'AWS::EC2::SpotFleet' "${TEMPLATE}"; then
    add_finding "asg-wrong-scaling-metric" "critical" \
      "Application Auto Scaling references EC2SpotFleetRequestAverageCPUUtilization but template uses a standard Auto Scaling Group (not Spot Fleet)." \
      "Use PredefinedMetricType ASGAverageCPUUtilization for AWS::AutoScaling::AutoScalingGroup target tracking policies."
  fi
fi

if grep -qE '!Select\s*\[\s*0\s*,\s*!GetAZs' "${TEMPLATE}"; then
  add_finding "static-az-index" "warning" \
    "Subnets pin Availability Zones via !Select [0, !GetAZs \"\"] which can fail when AZ-0 lacks capacity or instance types." \
    "Pass AvailabilityZones as a parameter list or map instead of hard-coded AZ indices."
fi

if grep -q 'AWS::EC2::NatGateway' "${TEMPLATE}" && grep -q 'PrivateSubnet\|private' "${TEMPLATE}"; then
  if ! grep -q 'AWS::EC2::VPCEndpoint' "${TEMPLATE}"; then
    add_finding "missing-vpc-endpoints" "warning" \
      "Private subnets use NAT Gateway egress but no Interface VPC Endpoints (SSM, Secrets Manager, SQS, CloudWatch Logs)." \
      "Add AWS::EC2::VPCEndpoint resources for private AWS API traffic or document NAT-only as an explicit assumption."
  fi
fi

if [[ "${FEDRAMP_PROFILE}" == "moderate" || "${FEDRAMP_PROFILE}" == "high" ]]; then
  if grep -qi 'AlbLogs\|AccessLogs\|access.log' "${TEMPLATE}"; then
    if grep -q 'SSEAlgorithm: AES256' "${TEMPLATE}" || grep -q 'SSEAlgorithm: "AES256"' "${TEMPLATE}"; then
      if ! grep -q 'aws:kms' "${TEMPLATE}"; then
        add_finding "alb-logs-sse-s3-only" "warning" \
          "ALB access log bucket appears to use SSE-S3 (AES256) rather than SSE-KMS for FedRAMP ${FEDRAMP_PROFILE} audit trails." \
          "Set BucketEncryption SSEAlgorithm to aws:kms with a customer managed key."
      fi
    fi
  fi
fi

if [[ -n "${target_rps}" ]] && [[ "${target_rps}" =~ ^[0-9]+$ ]] && [[ "${target_rps}" -ge "${HIGH_RPS_THRESHOLD}" ]]; then
  has_edge=false
  grep -qiE 'AWS::CloudFront|AWS::ElasticLoadBalancingV2::LoadBalancer.*network|Network Load Balancer|AWS::Route53' "${TEMPLATE}" && has_edge=true || true
  if grep -q 'AWS::ElasticLoadBalancingV2::LoadBalancer' "${TEMPLATE}"; then
    if [[ "${has_edge}" != "true" ]]; then
      add_finding "high-rps-without-edge-scale" "critical" \
        "Intent targets ${target_rps} RPS but template relies on ALB/ASG without CloudFront, NLB fan-out, or documented pre-warm strategy." \
        "Add edge caching (CloudFront), NLB + ALB tier, ALB pre-warm via AWS Support, or lower declared RPS in requirements."
    fi
  fi

  asg_max="$(grep -E 'MaxSize:|MaxSize ' "${TEMPLATE}" | grep -oE '[0-9]+' | sort -n | tail -1 || true)"
  if [[ -n "${asg_max}" && "${asg_max}" =~ ^[0-9]+$ ]]; then
    rps_per_instance=$(( target_rps / asg_max ))
    if [[ "${rps_per_instance}" -gt 10000 ]]; then
      add_finding "asg-capacity-vs-rps" "warning" \
        "ASG MaxSize ${asg_max} implies ~${rps_per_instance} RPS per instance at ${target_rps} RPS target — likely under-provisioned." \
        "Increase MaxSize, use larger instance types, or add horizontal edge scaling."
    fi
  fi
fi

if grep -q 'AWS::RDS::DBCluster' "${TEMPLATE}" && grep -qi 'Aurora' "${TEMPLATE}"; then
  reader_count="$(grep -c 'AWS::RDS::DBInstance' "${TEMPLATE}" || true)"
  if [[ "${reader_count}" -le 2 ]] && [[ "${workload_class}" == "high-throughput-web" || ( -n "${target_rps}" && "${target_rps}" -ge "${HIGH_RPS_THRESHOLD}" ) ]]; then
    add_finding "aurora-reader-autoscaling" "warning" \
      "High-throughput workload with Aurora but no Aurora Auto Scaling policy for read replicas." \
      "Add AWS::RDS::DBCluster scaling or additional reader instances for read-heavy spikes."
  fi
fi

if grep -q 'AWS::KMS::Key' "${TEMPLATE}"; then
  kms_service_count="$(grep -cE 'logs\.|secretsmanager|sns|sqs|elasticache|rds' "${TEMPLATE}" || true)"
  if [[ "${kms_service_count}" -ge 4 ]] && [[ "$(grep -c 'AWS::KMS::Key' "${TEMPLATE}")" -le 1 ]]; then
    add_finding "shared-cmk-blast-radius" "warning" \
      "Single CMK encrypts multiple tiers (logs, secrets, messaging, data) — increases lateral blast radius." \
      "Segment KMS keys by tier (data, queues, logging) per org baseline."
  fi
fi

MAX_TEMPLATE_LINES="${CFN_AUTHOR_MAX_TEMPLATE_LINES:-500}"
MAX_TEMPLATE_RESOURCES="${CFN_AUTHOR_MAX_TEMPLATE_RESOURCES:-30}"
line_count="$(wc -l < "${TEMPLATE}" | tr -d '[:space:]')"
resource_count="$(grep -cE '^[[:space:]]{4}Type:[[:space:]]+AWS::' "${TEMPLATE}" 2>/dev/null || echo 0)"
if [[ "${line_count}" -gt "${MAX_TEMPLATE_LINES}" ]] || [[ "${resource_count}" -gt "${MAX_TEMPLATE_RESOURCES}" ]]; then
  add_finding "monolith-template-size" "critical" \
    "Template has ${line_count} lines and ${resource_count} AWS resources (max ${MAX_TEMPLATE_LINES} lines / ${MAX_TEMPLATE_RESOURCES} resources)." \
    "Compose from catalog modules or nested stacks instead of a greenfield monolith; split by concern."
fi

critical=0
warning=0
if [[ ${#findings[@]} -gt 0 ]]; then
  for f in "${findings[@]}"; do
    sev="$(echo "${f}" | jq -r '.severity')"
    if [[ "${sev}" == "critical" ]]; then
      critical=$((critical + 1))
    else
      warning=$((warning + 1))
    fi
  done
fi

summary="PASS"
passed=true
blocked=false
if [[ "${critical}" -gt 0 ]]; then
  summary="FAIL"
  passed=false
  blocked=true
elif [[ "${warning}" -gt 0 ]]; then
  summary="NEEDS_REVIEW"
fi

jq -nc \
  --arg summary "${summary}" \
  --argjson critical "${critical}" \
  --argjson warning "${warning}" \
  --argjson findings "$(if [[ ${#findings[@]} -eq 0 ]]; then echo '[]'; else printf '%s\n' "${findings[@]}" | jq -s '.'; fi)" \
  '{architecture_summary: $summary, critical_count: $critical, warning_count: $warning, findings: $findings}' \
  > "${OUT}"

echo "architecture_lint_passed=${passed}"
echo "architecture_summary=${summary}"
echo "architecture_critical_count=${critical}"
echo "architecture_warning_count=${warning}"
echo "architecture_findings_path=${OUT}"
if [[ "${blocked}" == "true" ]]; then
  echo "architecture_blocked=true"
fi
if [[ "${summary}" == "NEEDS_REVIEW" ]]; then
  echo "architecture_needs_review=true"
fi

if [[ "${passed}" == "false" ]]; then
  exit 0
fi
