variable "stackgen_url" {
  type = string
}

variable "stackgen_token" {
  type      = string
  sensitive = true
}

variable "stackgen_project_id" {
  description = "Optional default project ID for Guild APIs that send org scope (webhooks, knowledge)."
  type        = string
  default     = ""
}

variable "guild_integration_scope" {
  description = "Passed to aios-foundation. Empty uses platform default; set to TENANT, PROJECT, or USER only when you need an explicit scope."
  type        = string
  default     = ""
}

variable "openai_api_key" {
  type      = string
  sensitive = true
  default   = ""
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
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "slack_bot_token" {
  type      = string
  sensitive = true
}

variable "slack_signing_secret" {
  type      = string
  sensitive = true
  default   = ""
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
  default   = ""
}
