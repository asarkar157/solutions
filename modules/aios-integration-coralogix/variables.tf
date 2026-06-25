variable "coralogix_api_key" {
  description = "Coralogix API key. Stored in Vault metadata as `coralogix_api_key`. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "coralogix_base_url" {
  description = "Coralogix API base URL for your domain (e.g. https://api.coralogix.com)."
  type        = string
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with Coralogix credentials (`coralogix_api_key`, `coralogix_base_url`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "coralogix-integration"
}

variable "description" {
  type    = string
  default = "Coralogix observability integration for logs, alerts, and metrics."
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
  description = "Container image for the Coralogix Guild integration. Verify against your Guild catalog (`GET /api/v1/integrations/types`)."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-coralogix:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
