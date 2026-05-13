variable "grafana_server" {
  description = "Base URL of the Grafana server (e.g. https://grafana.example.com)"
  type        = string
}

variable "grafana_token" {
  description = "Grafana service account token"
  type        = string
  sensitive   = true
}

variable "integration_name" {
  description = "Name of the Guild integration resource"
  type        = string
  default     = "grafana-integration"
}

variable "description" {
  description = "Description for the integration"
  type        = string
  default     = "Grafana observability integration for dashboard queries, alert state, and metric analysis"
}

variable "scope" {
  type    = string
  default = "PROJECT"
}

variable "enabled" {
  type    = bool
  default = true
}

variable "integration_image" {
  type    = string
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-grafana:main"
}

variable "env" {
  description = <<-EOT
    Optional map of plain-text environment variables injected into the Grafana
    integration container at launch (StackGen provider >= 0.1.17). Use for
    non-sensitive overrides such as proxy URLs, custom org IDs, or feature
    toggles. Sensitive values should go through `sg_secret` and be referenced
    via `secret_ref_ids`.
  EOT
  type        = map(string)
  default     = {}
}
