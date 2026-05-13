variable "gcp_credentials_json" {
  description = "GCP service account key JSON"
  type        = string
  sensitive   = true
}
variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}
variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}
variable "integration_name" {
  type    = string
  default = "gcp-production"
}
variable "integration_image" {
  type    = string
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-gcp:main"
}
variable "name_prefix" {
  type    = string
  default = ""
}

variable "env" {
  description = <<-EOT
    Optional map of plain-text environment variables injected into the GCP
    integration container at launch (StackGen provider >= 0.1.17). Use for
    non-sensitive overrides such as proxy URLs, regional flags, or feature
    toggles. Sensitive values should go through `sg_secret` and be
    referenced via `secret_ref_ids`.
  EOT
  type        = map(string)
  default     = {}
}
