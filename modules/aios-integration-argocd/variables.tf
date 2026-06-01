variable "server_url" {
  description = "Argo CD API server URL (e.g. https://argocd.example.com). Stored in Vault as `server_url`."
  type        = string
  default     = ""
}

variable "auth_token" {
  description = "Argo CD API token (preferred). Required with `server_url` when not using username/password."
  type        = string
  sensitive   = true
  default     = ""
}

variable "username" {
  description = "Optional Argo CD username when token auth is not used."
  type        = string
  default     = ""
}

variable "password" {
  description = "Optional Argo CD password paired with `username`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID (`server_url`, `auth_token` or `username`/`password`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "argocd-integration"
}

variable "description" {
  type    = string
  default = "Argo CD GitOps integration for application health, sync status, and deployment events."
}

variable "integration_type" {
  description = "Guild integration `type`. Default `argocd` — confirm against your StackGen catalog; use `kubernetes` only if `argocd` is unavailable."
  type        = string
  default     = "argocd"
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
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-argocd:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
