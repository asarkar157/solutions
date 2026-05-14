variable "grafana_server" {
  description = "Base URL of the Grafana server (e.g. https://grafana.example.com). Used to write the auto-created secret. Empty when `existing_secret_id` is supplied."
  type        = string
  default     = ""
}

variable "grafana_token" {
  description = "Grafana service account token. Used to write the auto-created secret. Empty when `existing_secret_id` is supplied. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = <<-EOT
    Optional ID of a pre-existing `sg_secret` holding Grafana credentials.
    When set, this module skips creating its own secret and binds the
    integration directly to the supplied secret. Mutually exclusive with
    `grafana_token` — set exactly one.
  EOT
  type        = string
  default     = ""
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
