variable "role_name" {
  description = "IAM role name for CloudFormation preview and drift read."
  type        = string
  default     = "AiosCfnPreviewTargetRole"
}

variable "policy_name" {
  description = "IAM managed policy name attached to the preview target role."
  type        = string
  default     = "AiosCfnPreviewTargetPolicy"
}

variable "trusted_assumer_arns" {
  description = <<-EOT
    IAM principal ARNs allowed to assume this role (e.g. Vault bastion role, EKS IRSA role).
    For local Vault dev, pass the bastion role ARN from stackgen-vault/docs/aws-bastion output.
  EOT
  type        = list(string)

  validation {
    condition     = length(compact(var.trusted_assumer_arns)) > 0
    error_message = "trusted_assumer_arns must contain at least one non-empty ARN."
  }
}
