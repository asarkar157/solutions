variable "base_url" {
  description = "GitLab instance base URL (e.g. https://gitlab.example.com). Stored in Vault metadata as `base_url`."
  type        = string
  default     = ""
}

variable "private_token" {
  description = "GitLab personal/project access token. Preferred vault key `private_token`. Mutually exclusive with `api_token` when creating a secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "api_token" {
  description = "Alias for GitLab API token when `private_token` is not used. Stored as `api_token` in Vault metadata."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with GitLab credentials (`base_url`, `private_token` or `api_token`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "gitlab-integration"
}

variable "description" {
  type    = string
  default = "GitLab SCM integration for pipelines, merge requests, and repository context."
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
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-gitlab:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
