variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant (no trailing slash)."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen personal access token."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "Optional StackGen project / org ID."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for Bedrock and the AWS integration."
  type        = string
  default     = "us-east-1"
}

variable "aws_role_arn" {
  description = "IAM role ARN the AWS integration assumes (tooling / remediation)."
  type        = string
}

variable "bedrock_use_iam_role" {
  description = "When true, Bedrock auth uses the Guild host IAM role (no static keys in Vault). When false, set aws_access_key_id and aws_secret_access_key."
  type        = bool
  default     = true
}

variable "aws_access_key_id" {
  description = "AWS access key for Bedrock (when bedrock_use_iam_role is false)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_secret_access_key" {
  description = "AWS secret key for Bedrock (when bedrock_use_iam_role is false)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_session_token" {
  description = "Optional STS session token for Bedrock static-key auth."
  type        = string
  sensitive   = true
  default     = ""
}
