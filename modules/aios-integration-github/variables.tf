variable "github_token" {
  description = "GitHub personal access token (requires repo, read:org scopes)"
  type        = string
  sensitive   = true
}

variable "integration_name" {
  type    = string
  default = "github-integration"
}

variable "description" {
  type    = string
  default = "GitHub SCM integration for repository operations, PRs, and code analysis"
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
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-github:main"
}
