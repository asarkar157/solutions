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

variable "openai_api_key" {
  description = "OpenAI API key. At least one of openai / anthropic / gemini must be set."
  type        = string
  sensitive   = true
  default     = ""
}

variable "anthropic_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "gemini_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "aws_role_arn" {
  description = "IAM role ARN the AWS integration will assume via Vault. Required — both the cost-optimizer and resource-janitor agents need read access to billing + resource state."
  type        = string
}

variable "aws_region" {
  description = "Default AWS region for the AWS integration."
  type        = string
  default     = "us-east-1"
}

variable "slack_bot_token" {
  description = "Slack Bot Token. Required for this scenario — the whole point is the weekly Slack summary."
  type        = string
  sensitive   = true
}

variable "inactivity_days" {
  description = "Threshold the resource janitor uses to flag a resource as unused."
  type        = number
  default     = 30
}
