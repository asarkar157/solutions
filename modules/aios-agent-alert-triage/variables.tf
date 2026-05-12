variable "model_names" {
  description = "Registered model names"
  type = object({
    gpt4o         = string
    claude_sonnet = string
    gemini_flash  = string
  })
}

variable "policy_ids" {
  description = "Policy IDs for guardrails"
  type = object({
    dangerous_ops = string
  })
}

variable "integration_names" {
  description = "Names of the integrations"
  type = object({
    grafana = string
    slack   = string
  })
}
