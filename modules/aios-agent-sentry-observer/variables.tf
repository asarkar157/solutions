variable "model_names" {
  description = "Named LLM model references from the root module"
  type = object({
    gpt4o         = string
    claude_sonnet = string
    gemini_flash  = string
  })
}

variable "policy_ids" {
  description = "Policy IDs from the root module for agent policy attachments"
  type = object({
    dangerous_ops        = string
    data_risk_pii        = string
    sentry_observability = string
  })
}

variable "integration_names" {
  description = "Integration names passed from the root module"
  type = object({
    sentry = string
  })
}
