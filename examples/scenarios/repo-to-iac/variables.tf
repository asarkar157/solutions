variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant (no trailing slash)."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen personal access token (also used to authenticate the StackGen Consumer MCP)."
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
  description = "GitHub PAT (repo + read:org). Required — the agent reads the target repository to infer IaC."
  type        = string
  sensitive   = true
}

variable "github_repo_url" {
  description = "Default repo to demo with. Optional — the workflow accepts any GitHub URL at run-time."
  type        = string
  default     = ""
}
