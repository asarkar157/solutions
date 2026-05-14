variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}
variable "policy_ids" {
  type = object({
    dangerous_ops            = string
    prod_write_gate          = optional(string, "")
    sre_remediation          = optional(string, "")
    container_shell_hitl     = optional(string, "")
    blast_radius_limit       = optional(string, "")
    freeze_window            = optional(string, "")
    data_risk_pii            = optional(string, "")
    post_action_verification = optional(string, "")
    azure_tool_governance    = optional(string, "")
  })
}
# =============================================================================
# Self-contained integration wiring.
# =============================================================================

variable "azure_secret_id" {
  description = "Optional `sg_secret` ID for Azure credentials. When set, the module provisions an internal Azure Guild integration."
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional `sg_secret` ID for Slack credentials. When set, the module provisions an internal Slack Guild integration so the agent can post incident updates."
  type        = string
  default     = ""
}

variable "existing_azure_integration_name" {
  description = "Optional Guild integration name to share an existing Azure integration."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional Guild integration name to share an existing Slack integration."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / workflow / runbook / integration resource names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}
variable "azure_readonly_tools" {
  type    = list(string)
  default = []
}
variable "clickhouse_inspector_agent_name" {
  type    = string
  default = ""
}
variable "agent_budget" {
  type    = number
  default = 20
}

variable "secret_names" {
  type    = map(string)
  default = {}
}

variable "reader_principal_id" {
  type    = string
  default = ""
}

variable "azure_role_scope" {
  type    = string
  default = ""
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow_name>::<stage_id>" where workflow_name is the sg_workflow.name in this module and stage_id matches the stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}

