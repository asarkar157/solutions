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
