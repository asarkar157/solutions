variable "stackgen_url" {
  description = "Base URL of the StackGen platform. Configure the root module provider \"sg\" with stackgen_url set to this value."
  type        = string
}

variable "stackgen_token" {
  description = "Bearer token for StackGen API authentication. Configure the root module provider \"sg\" with stackgen_token set to this value."
  type        = string
  sensitive   = true
  default     = ""
}

variable "stackgen_insecure" {
  description = "Allow plaintext HTTP connections (for local development only). Must match the root provider \"sg\" insecure setting if set."
  type        = bool
  default     = false
}

variable "org_id" {
  description = "Organization ID for StackGen. Must match the root provider \"sg\" org_id if set."
  type        = string
  default     = ""
}

variable "llm_api_keys" {
  description = "LLM provider API keys for vault secrets"
  type = object({
    openai    = optional(string, "")
    anthropic = optional(string, "")
    gemini    = optional(string, "")
  })
  sensitive = true
  default   = {}
}

variable "name_prefix" {
  description = "Optional prefix for all resource names (prevents collisions in multi-tenant deployments)"
  type        = string
  default     = ""
}
