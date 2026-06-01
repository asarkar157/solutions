variable "api_token" {
  description = "PagerDuty REST API token. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with PagerDuty credentials."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "pagerduty-integration"
}

variable "description" {
  type    = string
  default = "PagerDuty integration for incident lifecycle, notes, and on-call routing."
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
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-pagerduty:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
