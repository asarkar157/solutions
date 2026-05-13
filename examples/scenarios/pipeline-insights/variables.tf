variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant (no trailing slash)."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen personal access token."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "Optional StackGen project / org ID."
  type        = string
  default     = ""
}

variable "openai_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "anthropic_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "gemini_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_token" {
  description = "GitHub PAT (needs repo + read:org scopes). Required — both agents need GitHub API access."
  type        = string
  sensitive   = true
}

variable "slack_bot_token" {
  description = "Slack Bot Token. Optional — Slack integration is wired into both agents when set."
  type        = string
  sensitive   = true
  default     = ""
}

variable "service_catalog" {
  description = <<-EOT
    Optional map of `service_name` → repository (`owner/name`) consumed by the
    release-tracker agent so operators can ask "what's the latest version of X?"
    without naming the repo each time.
  EOT
  type        = map(string)
  default     = {}
}

variable "image_namespace_template" {
  description = "Container image namespace template used by release-tracker to derive image refs from `service_name`."
  type        = string
  default     = "ghcr.io/{{org}}/{{service}}"
}
