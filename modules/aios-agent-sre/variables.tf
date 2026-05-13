variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
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

variable "policy_create_flags" {
  description = "Must align with module.policies policy_create_flags (same semantics as create_policies). Used only for Terraform count on optional attachments — avoids unknown counts when policy IDs are (known after apply). An attachment is created only when the matching flag is true and the corresponding policy_ids field is non-empty."
  type = object({
    sre_remediation          = optional(bool, true)
    prod_write_gate          = optional(bool, true)
    tier0_service_protection = optional(bool, true)
    blast_radius_limit       = optional(bool, true)
    freeze_window            = optional(bool, true)
    data_risk_pii            = optional(bool, true)
    post_action_verification = optional(bool, true)
  })
  default = {}
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

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow_name>::<stage_id>" using each sg_workflow.name (e.g. incident-response::collect-signals) and the stage_id string.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}

