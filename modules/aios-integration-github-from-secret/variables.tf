variable "name" {
  description = <<-EOT
    Logical name for the generated secret. The resulting `sg_secret` is named
    `$${name}-provider-github-vault`. Defaults to `github-pat`.
  EOT
  type        = string
  default     = "github-pat"
}

variable "github_token" {
  description = <<-EOT
    Raw GitHub PAT (or fine-grained token). Written as the `GIT_TOKEN` metadata
    key on a `Provider`/`github` shaped `sg_secret`. The Ubuntu Guild
    integration's `pre_launch.sh` script surfaces `GIT_TOKEN`, `GIT_HOST`,
    `GIT_USERNAME` as environment variables in every shell the agent spawns,
    so `git clone https://github.com/...` and `gh auth status` Just Work
    without an explicit token-capture step.

    This module is the **short-term stopgap** until the Guild Ubuntu image
    natively unpacks `SCM/github` shaped secrets — once that lands the
    Provider/github sibling-secret becomes unnecessary.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = trimspace(var.github_token) != ""
    error_message = "github_token must be a non-empty PAT."
  }
}

variable "git_host" {
  description = "Host the PAT authenticates against. Surfaces as `GIT_HOST` env var. Default `github.com`."
  type        = string
  default     = "github.com"
}

variable "git_username" {
  description = <<-EOT
    Git username paired with `GIT_TOKEN`. Surfaces as `GIT_USERNAME` env var.
    Default `x-access-token` works for both classic and fine-grained GitHub
    PATs (`https://x-access-token:<pat>@github.com/...`).
  EOT
  type        = string
  default     = "x-access-token"
}

variable "description" {
  description = "Description for the generated `sg_secret`. Shows in the Vault UI."
  type        = string
  default     = "Provider/github shape — surfaced as GIT_TOKEN/GIT_HOST/GIT_USERNAME env in Ubuntu sandboxes so `git` + `gh` are pre-authed."
}
