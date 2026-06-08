#!/usr/bin/env bash
# architecture-lint_test.sh — smoke test architecture-lint against known anti-patterns.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_ROOT="$(mktemp -d)"
trap 'rm -rf "${WORK_ROOT}"' EXIT

mkdir -p "${WORK_ROOT}/generated"
printf '{"intent":"High-throughput betting 1000000 RPS","target_rps":1000000,"workload_class":"high-throughput-web","environment":"staging"}' \
  > "${WORK_ROOT}/requirements_spec.json"

cat > "${WORK_ROOT}/generated/template.yaml" <<'YAML'
Resources:
  AppAsg:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      MaxSize: 20
  ScalePolicy:
    Type: AWS::AutoScaling::ScalingPolicy
    Properties:
      TargetTrackingConfiguration:
        PredefinedMetricSpecification:
          PredefinedMetricType: EC2SpotFleetRequestAverageCPUUtilization
  Alb:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  Nat:
    Type: AWS::EC2::NatGateway
  PrivateSubnet:
    Type: AWS::EC2::Subnet
YAML

export WORK_ROOT FEDRAMP_PROFILE=moderate CFN_AUTHOR_HIGH_RPS_THRESHOLD=100000
out="$(bash "${ROOT}/architecture-lint.sh")"
printf '%s\n' "${out}"

echo "${out}" | grep -q 'architecture_summary=FAIL' || { echo "FAIL: expected FAIL summary" >&2; exit 1; }
jq -e '.findings[] | select(.id == "asg-wrong-scaling-metric")' "${WORK_ROOT}/generated/architecture-findings.json" >/dev/null \
  || { echo "FAIL: expected asg-wrong-scaling-metric finding" >&2; exit 1; }

WORK_ROOT2="$(mktemp -d)"
mkdir -p "${WORK_ROOT2}/generated"
printf '{"intent":"large stack","environment":"staging"}' > "${WORK_ROOT2}/requirements_spec.json"
python3 - <<'PY' > "${WORK_ROOT2}/generated/template.yaml"
for i in range(600):
    print(f"  R{i}:")
    print("    Type: AWS::S3::Bucket")
PY
export WORK_ROOT="${WORK_ROOT2}" CFN_AUTHOR_MAX_TEMPLATE_LINES=500 CFN_AUTHOR_MAX_TEMPLATE_RESOURCES=30
out2="$(bash "${ROOT}/architecture-lint.sh")"
echo "${out2}" | grep -q 'architecture_summary=FAIL' || { echo "FAIL: expected monolith FAIL" >&2; exit 1; }
jq -e '.findings[] | select(.id == "monolith-template-size")' "${WORK_ROOT2}/generated/architecture-findings.json" >/dev/null \
  || { echo "FAIL: expected monolith-template-size finding" >&2; exit 1; }
rm -rf "${WORK_ROOT2}"

echo "OK: architecture-lint detects ASG metric mismatch, high-RPS gaps, and monolith size"
