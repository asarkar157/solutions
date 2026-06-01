variable "management_url" {
  description = "PAN-OS management URL (e.g. https://fw.example.com). Stored in Vault as `management_url`. Mutually exclusive with `existing_secret_id`."
  type        = string
  default     = ""
}

variable "api_key" {
  description = "PAN-OS XML API key (preferred). Stored in Vault as `api_key`. Use with `management_url` when creating a new secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "username" {
  description = "Optional PAN-OS username when API key auth is insufficient. Stored in Vault as `username`."
  type        = string
  default     = ""
}

variable "password" {
  description = "Optional PAN-OS password paired with `username`. Stored in Vault as `password`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with PAN-OS credentials (`management_url`, `api_key`, and optional `username`/`password` metadata)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "paloalto-integration"
}

variable "integration_type" {
  description = "Guild integration `type` string. Default `paloalto` — confirm against your Guild integration catalog before apply."
  type        = string
  default     = "paloalto"
}

variable "description" {
  type    = string
  default = "Palo Alto Networks PAN-OS firewall integration for read-only policy, traffic, and threat log analysis."
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
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-paloalto:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
