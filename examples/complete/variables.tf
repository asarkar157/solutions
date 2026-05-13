variable "stackgen_url" {
  type = string
}

variable "stackgen_token" {
  type      = string
  sensitive = true
}

# Optional StackGen project (organization) UUID — sent as orgId on scoped Guild calls when set.
# Match module.foundation.project_id when using foundation’s project_id variable.
variable "stackgen_project_id" {
  type    = string
  default = ""
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

# Grafana integration is optional. When `grafana_token` is non-empty, the
# example wires the Grafana integration AND the alert-triage agent (which
# needs both Grafana and Slack) so incoming Grafana alerts can be triaged
# and posted back to Slack. Leave empty to skip that wiring.
variable "grafana_server" {
  description = "Base URL of the Grafana server (e.g. https://grafana.example.com). Empty disables the Grafana integration + alert-triage."
  type        = string
  default     = ""
}

variable "grafana_token" {
  description = "Grafana service account token. Empty disables the Grafana integration + alert-triage."
  type        = string
  sensitive   = true
  default     = ""
}

variable "langfuse_public_key" {
  type    = string
  default = ""
}

variable "langfuse_secret_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "langfuse_host" {
  type    = string
  default = "https://cloud.langfuse.com"
}
