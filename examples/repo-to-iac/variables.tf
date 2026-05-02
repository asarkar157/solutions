variable "stackgen_url" {
  description = "StackGen API base URL (no trailing slash)."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen PAT (provider + MCP Authorization)."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "StackGen project ID."
  type        = string
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
  description = "GitHub PAT for the GitHub MCP integration."
  type        = string
  sensitive   = true
}

variable "create_stackgen_mcp_integrations" {
  description = "Create one Vault Other/mcp secret and one Guild MCP integration (stackgen_url + /api/mcp/user; transport streamable_http)."
  type        = bool
  default     = true
}

variable "stackgen_mcp_secret_name" {
  type    = string
  default = "stackgen-mcp-credentials"
}

variable "stackgen_mcp_integration_name" {
  type    = string
  default = "stackgen-mcp"
}
