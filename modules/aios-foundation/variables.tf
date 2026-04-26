variable "guild_url" {
  description = "Base URL of the StackGen platform (includes Guild and Vault APIs)"
  type        = string
}

variable "guild_token" {
  description = "Bearer token for StackGen API authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "guild_insecure" {
  description = "Allow plaintext HTTP connections (for local development only)"
  type        = bool
  default     = false
}

variable "org_id" {
  description = "Organization ID for StackGen"
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

variable "models" {
  description = "Model configuration overrides. Keys are logical names, values define provider and model ID."
  type = map(object({
    provider_name = string
    model_id      = string
    good_for_task = optional(string, "")
  }))
  default = {
    gpt4o = {
      provider_name = "openai"
      model_id      = "gpt-4o"
      good_for_task = "tool_calling"
    }
    claude_sonnet = {
      provider_name = "anthropic"
      model_id      = "claude-sonnet-4-6"
      good_for_task = "planning"
    }
    gemini_flash = {
      provider_name = "gemini"
      model_id      = "gemini-3-flash-preview"
      good_for_task = "efficiency"
    }
  }
}
