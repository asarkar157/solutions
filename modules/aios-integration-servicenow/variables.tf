variable "instance_url" {
  description = "ServiceNow instance URL (e.g. https://your-org.service-now.com). Stored in Vault as `base_url` for the Guild integration. Mutually exclusive with `existing_secret_id`."
  type        = string
  default     = ""
}

variable "username" {
  description = "ServiceNow username for basic auth. Required with `instance_url` and `password` when creating a new secret."
  type        = string
  default     = ""
}

variable "password" {
  description = "ServiceNow password for basic auth. Required with `instance_url` and `username` when creating a new secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with ServiceNow credentials (`base_url`, `username`, `password` metadata)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "servicenow-integration"
}

variable "description" {
  type    = string
  default = "ServiceNow ITSM integration for incident and change ticket lifecycle."
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
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-servicenow:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
