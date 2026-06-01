variable "base_url" {
  description = "Base URL of the internal operator console or service catalog API (e.g. https://console.internal.example.com/api). Required when creating a new secret."
  type        = string
  default     = ""
}

variable "api_key" {
  description = "Optional bearer token for the internal API. Stored in Vault as `auth_header` (`Bearer <token>`). Omit for unauthenticated internal endpoints."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with REST API credentials (`base_url`, optional `auth_header`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "internal-tool-integration"
}

variable "description" {
  type    = string
  default = "Internal tooling REST API — PrivateSaaS operator console, service catalog, ownership, and dependency lookups."
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
  description = "Guild `restapi` integration image. Default matches stackgen-guild catalog (`integration-restapi`)."
  type        = string
  default     = "ghcr.io/appcd-dev/integration-restapi:latest"
}

variable "env" {
  type    = map(string)
  default = {}
}
