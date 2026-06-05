output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "vpc_id" {
  description = "VPC hosting the private EKS workloads"
  value       = aws_vpc.main.id
}

output "configure_kubectl" {
  description = "Merge kubeconfig using the EKS cluster access IAM role (recommended)"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name} --role-arn ${aws_iam_role.eks_cluster_access.arn} --alias ${aws_eks_cluster.main.name}"
}

output "configure_kubectl_script" {
  description = "Path to helper script that validates the role ARN before calling AWS CLI"
  value       = "${path.module}/scripts/configure-kubeconfig.sh"
}

output "eks_cluster_access_role_arn" {
  description = "IAM role ARN to pass to aws eks update-kubeconfig --role-arn"
  value       = aws_iam_role.eks_cluster_access.arn
}

output "eks_cluster_access_role_name" {
  description = "IAM role name for EKS kubectl/AWS CLI access"
  value       = aws_iam_role.eks_cluster_access.name
}

output "eks_access_trusted_principals" {
  description = "IAM principals allowed to assume the EKS access role"
  value       = local.eks_access_trusted_principals
}

output "assume_eks_access_role_command" {
  description = "Assume the EKS access role in your shell (alternative to --role-arn on update-kubeconfig)"
  value       = "aws sts assume-role --role-arn ${aws_iam_role.eks_cluster_access.arn} --role-session-name eks-kubectl"
}

output "aiden_runner_namespaces" {
  description = "Kubernetes namespace for each remote runner deployment, keyed by runner name"
  value       = { for k, v in helm_release.aiden_remote_runner : k => v.namespace }
}

output "aiden_server_url" {
  description = "Effective SERVER_URL passed to all runner deployments"
  value       = local.aiden_server_url
}

output "aiden_runner_image" {
  description = "Fully qualified container image (repository:tag) deployed to all runners"
  value       = "${var.aiden_runner_image_name}:${var.aiden_runner_image_version}"
}

output "verify_runner_pods" {
  description = "kubectl commands to check pod status for each remote runner deployment"
  value = {
    for k, v in helm_release.aiden_remote_runner : k =>
    "kubectl get pods -n ${v.namespace} -l app.kubernetes.io/name=remote-runner 2>/dev/null || kubectl get pods -n ${v.namespace}"
  }
}

output "verify_runner_logs" {
  description = "kubectl commands to stream logs for each remote runner deployment"
  value = {
    for k, v in helm_release.aiden_remote_runner : k =>
    "kubectl logs -n ${v.namespace} -l app.kubernetes.io/name=remote-runner -f --tail=100"
  }
}

output "helm_release_statuses" {
  description = "helm status commands for each remote runner deployment"
  value = {
    for k, v in helm_release.aiden_remote_runner : k =>
    "helm status ${k} -n ${v.namespace}"
  }
}
