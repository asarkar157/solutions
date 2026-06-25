variable "digitalocean_token" {
  description = "DigitalOcean personal access token. Stored in Vault metadata as `digitalocean_token`. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with DigitalOcean credentials (`digitalocean_token`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "digitalocean-integration"
}

variable "description" {
  type    = string
  default = "DigitalOcean cloud integration for droplets, Kubernetes clusters, and account resources."
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
  description = "Container image for the DigitalOcean Guild integration. Verify against your Guild catalog (`GET /api/v1/integrations/types`)."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-digitalocean:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
