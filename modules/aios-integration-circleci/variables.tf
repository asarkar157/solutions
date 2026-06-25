variable "circleci_token" {
  description = "CircleCI personal API token. Stored in Vault metadata as `circleci_token`. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with CircleCI credentials (`circleci_token`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "circleci-integration"
}

variable "description" {
  type    = string
  default = "CircleCI DevOps integration for pipeline failures and CI/CD health."
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
  description = "Container image for the CircleCI Guild integration. Verify against your Guild catalog (`GET /api/v1/integrations/types`)."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-circleci:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
