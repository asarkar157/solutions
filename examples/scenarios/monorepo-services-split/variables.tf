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
  type    = string
  default = ""
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
  description = "GitHub PAT (repo read + PR write for guidance/extract PRs)."
  type        = string
  sensitive   = true
}

variable "github_repo_url" {
  description = "Default monorepo URL for the demo talk track."
  type        = string
  default     = ""
}

variable "default_branch" {
  type    = string
  default = "main"
}

variable "enable_cursor_integration" {
  type    = bool
  default = false
}

variable "cursor_mcp_integration_name" {
  type    = string
  default = ""
}

variable "enable_github_webhook" {
  type    = bool
  default = false
}
