variable "api_key" {
  description = "FireHydrant API token (fhb-...). Stored in Vault metadata as `api_token`. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "base_url" {
  description = "FireHydrant API base URL. Defaults to https://api.firehydrant.io when empty."
  type        = string
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with FireHydrant credentials (`api_token`, optional `base_url`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "firehydrant-integration"
}

variable "description" {
  type    = string
  default = "FireHydrant incident management integration for timelines, responders, and runbook links."
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
  description = "Container image for the FireHydrant Guild integration. Verify against your Guild catalog (`GET /api/v1/integrations/types`)."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-firehydrant:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
