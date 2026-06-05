#!/usr/bin/env bash
# Configure kubectl for the Aiden EKS cluster using the Terraform-managed access role.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-aiden-k8s-dev}"
ROLE_ARN="${ROLE_ARN:-}"

if [[ -z "${ROLE_ARN}" ]]; then
  if ! command -v terraform >/dev/null 2>&1; then
    echo "ERROR: terraform not found. Set ROLE_ARN or install Terraform." >&2
    exit 1
  fi
  ROLE_ARN="$(cd "${MODULE_DIR}" && terraform output -raw eks_cluster_access_role_arn 2>/dev/null || true)"
fi

if [[ ! "${ROLE_ARN}" =~ ^arn:aws:iam::[0-9]{12}:role/.+ ]]; then
  cat >&2 <<EOF
ERROR: Invalid or missing IAM role ARN for --role-arn.

Got: ${ROLE_ARN:-<empty>}

Common causes:
  - terraform output run outside ${MODULE_DIR} (empty state → warning text passed as ARN)
  - Infrastructure not applied yet (run: terraform apply)

Fix — use the role ARN directly (replace account ID if needed):
  aws eks update-kubeconfig \\
    --region ${AWS_REGION} \\
    --name ${CLUSTER_NAME} \\
    --role-arn arn:aws:iam::ACCOUNT_ID:role/aiden-k8s-dev-eks-access \\
    --alias ${CLUSTER_NAME}

Or from this module directory after apply:
  cd ${MODULE_DIR}
  $(basename "$0")

Override:
  ROLE_ARN=arn:aws:iam::123456789012:role/aiden-k8s-dev-eks-access $0
EOF
  exit 1
fi

aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${CLUSTER_NAME}" \
  --role-arn "${ROLE_ARN}" \
  --alias "${CLUSTER_NAME}"

echo "Kubeconfig updated. Context: ${CLUSTER_NAME}"
echo "Role ARN: ${ROLE_ARN}"
kubectl config use-context "${CLUSTER_NAME}" 2>/dev/null || true
kubectl get nodes
