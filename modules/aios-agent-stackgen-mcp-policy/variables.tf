variable "stackgen_mcp_url" {
  description = "StackGen MCP endpoint URL. Paths containing /mcp/sse set Vault transport to sse; otherwise streamable_http (e.g. https://HOST/api/mcp/user)."
  type        = string
  default     = "https://app.stackgen.com/api/mcp/sse"
}

variable "stackgen_api_token" {
  description = "The authentication token for StackGen MCP"
  type        = string
  sensitive   = true
}

variable "model_names" {
  description = "Map of models available to use"
  type        = map(string)
}
