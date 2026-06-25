variable "civo_api_key" {
  description = "Civo API key. Stored in Vault metadata as `civo_api_key`. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with Civo credentials (`civo_api_key`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "civo-integration"
}

variable "description" {
  type    = string
  default = "Civo cloud integration for Kubernetes clusters and cloud resources."
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
  description = "Container image for the Civo Guild integration. Verify against your Guild catalog (`GET /api/v1/integrations/types`)."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-civo:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
