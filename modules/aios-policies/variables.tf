variable "create_policies" {
  description = "Map of booleans controlling which policies to create. Set a key to false to skip that policy."
  type = object({
    dangerous_ops            = optional(bool, true)
    sre_remediation          = optional(bool, true)
    hitl_approval_evaluation = optional(bool, true)
    prod_write_gate          = optional(bool, true)
    tier0_service_protection = optional(bool, true)
    blast_radius_limit       = optional(bool, true)
    freeze_window            = optional(bool, true)
    data_risk_pii            = optional(bool, true)
    post_action_verification = optional(bool, true)
    azure_tool_governance    = optional(bool, true)
    google_tool_governance   = optional(bool, true)
    container_shell_hitl     = optional(bool, true)
    langfuse_observability   = optional(bool, true)
  })
  default = {}
}

variable "create_policy_bundle" {
  description = "Whether to create the standard-guardrails policy bundle"
  type        = bool
  default     = true
}
