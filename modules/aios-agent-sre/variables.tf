variable "model_names" {
  description = "Named LLM model references from the foundation module"
  type = object({
    gpt4o         = string
    claude_sonnet = string
    gemini_flash  = string
  })
}

variable "policy_ids" {
  description = "Policy IDs from the policies module for agent policy attachments"
  type = object({
    dangerous_ops            = string
    sre_remediation          = optional(string, "")
    prod_write_gate          = optional(string, "")
    tier0_service_protection = optional(string, "")
    blast_radius_limit       = optional(string, "")
    freeze_window            = optional(string, "")
    data_risk_pii            = optional(string, "")
    post_action_verification = optional(string, "")
  })
}

variable "integration_names" {
  description = "Map of integration names to connect to agents (grafana, slack, linear)"
  type        = map(string)
  default     = {}
}

variable "agent_budgets" {
  description = "Daily budget limits (USD) per agent"
  type = object({
    auto_remediation   = optional(number, 25)
    incident           = optional(number, 25)
    triage             = optional(number, 15)
    change_correlation = optional(number, 15)
    risk_posture       = optional(number, 15)
  })
  default = {}
}

variable "workflow_approve" {
  description = "When true, Guild approves workflow drafts via API after apply."
  type        = bool
  default     = true
}
