variable "stackgen_url" {
  description = "StackGen / Guild base URL."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen PAT."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "Optional org / project ID."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for Bedrock and CloudFormation."
  type        = string
  default     = "us-east-1"
}

variable "aws_role_arn" {
  description = "Existing IAM role for AWS integration. Required when create_cfn_preview_iam_role is false."
  type        = string
  default     = ""

  validation {
    condition     = var.create_cfn_preview_iam_role || trimspace(var.aws_role_arn) != ""
    error_message = "Set aws_role_arn when create_cfn_preview_iam_role is false."
  }
}

variable "create_cfn_preview_iam_role" {
  description = "When true, provisions aios-cfn-preview-iam (change-set preview + drift read). Requires trusted_assumer_arns."
  type        = bool
  default     = false
}

variable "trusted_assumer_arns" {
  description = "Principals that may assume the CFN preview role (e.g. VaultTestBastionRole ARN from stackgen-vault/docs/aws-bastion)."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.create_cfn_preview_iam_role || length(compact(var.trusted_assumer_arns)) > 0
    error_message = "trusted_assumer_arns must contain at least one ARN when create_cfn_preview_iam_role is true."
  }
}

variable "cfn_preview_role_name" {
  description = "IAM role name when create_cfn_preview_iam_role is true."
  type        = string
  default     = "AiosCfnPreviewTargetRole"
}

variable "github_token" {
  description = "GitHub PAT for template catalog and PRs."
  type        = string
  sensitive   = true
}

variable "target_repository_full_name" {
  description = "org/repo for CFN templates."
  type        = string
}

variable "bedrock_use_iam_role" {
  description = "Use Guild host IAM role for Bedrock."
  type        = bool
  default     = true
}

variable "aws_access_key_id" {
  type      = string
  sensitive = true
  default   = ""
}

variable "aws_secret_access_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "aws_session_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "enable_drift_schedule" {
  description = "Enable daily drift management cron."
  type        = bool
  default     = true
}

variable "enable_drift_webhook" {
  description = "Register sg_webhook for cloudformation-drift-management."
  type        = bool
  default     = false
}
