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

variable "env" {
  description = <<-EOT
    Optional map of plain-text environment variables injected into the GitHub
    integration container at launch (StackGen provider >= 0.1.17). Use for
    non-sensitive overrides such as proxy URLs or feature toggles. Sensitive
    values should go through `sg_secret` and be referenced via
    `secret_ref_ids`.
  EOT
  type        = map(string)
  default     = {}
}
