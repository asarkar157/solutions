variable "role_name" {
  description = "IAM role name in the customer AWS account."
  type        = string
  default     = "stackgen-aios-readonly"
}

variable "bastion_role_arn" {
  description = "StackGen bastion role ARN from data.sg_vault_aws_config.bastion_role_arn (Principal.AWS in the trust policy)."
  type        = string
  default     = "arn:aws:iam::239541129941:role/stackgen-bastion"

  validation {
    condition     = trimspace(var.bastion_role_arn) != ""
    error_message = "bastion_role_arn is required — fetch from data.sg_vault_aws_config for your StackGen workspace."
  }
}

variable "external_id" {
  description = "Workspace external ID from data.sg_vault_aws_config.external_id (sts:ExternalId on AssumeRole)."
  type        = string

  validation {
    condition     = trimspace(var.external_id) != ""
    error_message = "external_id is required — fetch from data.sg_vault_aws_config for your StackGen workspace."
  }
}

variable "managed_policy_arns" {
  description = "AWS managed or customer policy ARNs to attach (ReadOnlyAccess is sufficient for most SRE MCP workflows)."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}
