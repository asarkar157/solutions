variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant (no trailing slash). Example: https://main.dev.stackgen.com"
  type        = string
}

variable "stackgen_token" {
  description = "StackGen personal access token. Generate one from the Guild UI under your profile."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "Optional StackGen project / org ID. Leave empty unless your tenant requires explicit project scope."
  type        = string
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key. At least one of openai / anthropic / gemini must be set so the foundation module registers a model."
  type        = string
  sensitive   = true
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key."
  type        = string
  sensitive   = true
  default     = ""
}

variable "gemini_api_key" {
  description = "Gemini API key."
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_role_arn" {
  description = "IAM role ARN the AWS integration will assume via Vault. Required."
  type        = string
}

variable "aws_region" {
  description = "Default AWS region for the AWS integration."
  type        = string
  default     = "us-east-1"
}

variable "slack_bot_token" {
  description = "Slack Bot Token. Optional: leave empty to skip the Slack integration in this scenario (the agent still runs in Guild chat)."
  type        = string
  sensitive   = true
  default     = ""
}
