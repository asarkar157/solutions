variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen personal access token."
  type        = string
  sensitive   = true
}

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

variable "github_token" {
  description = "GitHub PAT with read (+ write for bootstrap/drift PR workflows)."
  type        = string
  sensitive   = true
}

variable "grafana_server" {
  description = "Grafana base URL."
  type        = string
}

variable "grafana_token" {
  description = "Grafana service account token."
  type        = string
  sensitive   = true
}

variable "slack_bot_token" {
  description = "Slack bot token for weekly digest."
  type        = string
  sensitive   = true
}

variable "openslo_repository_full_name" {
  description = "GitHub repo holding OpenSLO YAML (org/name)."
  type        = string
}

variable "slo_report_webhook_url" {
  description = "Optional outbound webhook for JSON digest POST."
  type        = string
  default     = ""
}

variable "slack_channel_hint" {
  description = "Plain-language Slack channel hint for digests."
  type        = string
  default     = "#sre-alerts"
}

variable "discovery_dashboard_tags" {
  description = "Optional Grafana dashboard tag filters for discovery/drift scans."
  type        = list(string)
  default     = []
}
