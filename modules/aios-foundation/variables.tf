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

variable "project_id" {
  description = "Default project (organization) ID for scoped Guild/API calls. Must match the root provider \"sg\" project_id when set (preferred over deprecated org_id)."
  type        = string
  default     = ""
}

variable "org_id" {
  description = "Deprecated: use project_id on the root provider \"sg\" instead. Retained for backward compatibility with older root modules."
  type        = string
  default     = ""
}

variable "guild_integration_scope" {
  description = "When set to a non-empty value, applies that Guild IntegrationScope to LLM model providers and models (TENANT, PROJECT, or USER). Leave empty (default) to use the platform default and avoid forcing tenant-level scope."
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
