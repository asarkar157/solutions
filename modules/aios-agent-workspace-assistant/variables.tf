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
    dangerous_ops          = string
    google_tool_governance = optional(string, "")
  })
}
# =============================================================================
# Self-contained integration wiring.
#
# Google + Linear: no `aios-integration-google` / `aios-integration-linear`
# Vault-backed wrappers exist in this repo (Linear is OAuth-based via a
# credential provider). Pass `existing_*_integration_name` for those.
# Slack: provision internally from a secret ID, OR override with an existing
# integration name.
# =============================================================================

variable "existing_google_integration_name" {
  description = "Optional Guild integration name for Google Workspace. No aios-integration-google wrapper exists; pass a pre-provisioned name to wire Gmail/Calendar/Drive."
  type        = string
  default     = ""
}

variable "linear_credential_provider_id" {
  description = "Optional OAuth credential provider ID for Linear. When set, the module provisions an internal Linear Guild integration."
  type        = string
  default     = ""
}

variable "existing_linear_integration_name" {
  description = "Optional Guild integration name to share an existing Linear integration. Takes precedence over `linear_credential_provider_id`."
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional `sg_secret` ID for Slack. When set, the module provisions an internal Slack Guild integration."
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
variable "google_readonly_tools" {
  type    = list(string)
  default = []
}
variable "linear_readonly_tools" {
  type    = list(string)
  default = []
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

