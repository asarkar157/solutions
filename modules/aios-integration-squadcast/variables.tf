variable "squadcast_refresh_token" {
  description = "SquadCast OAuth refresh token. Stored in Vault metadata as `squadcast_refresh_token`. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "squadcast_region" {
  description = "SquadCast data region (`us` or `eu`). Stored in Vault metadata as `squadcast_region`."
  type        = string
  default     = "us"
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with SquadCast credentials (`squadcast_refresh_token`, `squadcast_region`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "squadcast-integration"
}

variable "description" {
  type    = string
  default = "SquadCast incident management integration for incidents, on-call schedules, and escalation policies."
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
  description = "Container image for the SquadCast Guild integration. Verify against your Guild catalog (`GET /api/v1/integrations/types`)."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-squadcast:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
