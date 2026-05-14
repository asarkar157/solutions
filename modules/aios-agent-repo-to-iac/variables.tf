variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Policy IDs from aios-policies (typically dangerous_ops)"
  type = object({
    dangerous_ops = string
  })
}

# =============================================================================
# Self-contained integration wiring (replaces the old `github_integration_name`
# input). StackGen MCP stays consumer-provided — it is a tenant-level singleton
# with no `aios-integration-stackgen-mcp` wrapper.
# =============================================================================

variable "github_secret_id" {
  description = "Optional `sg_secret` ID for the GitHub PAT. When set (and `existing_github_integration_name` is empty), this module provisions an internal GitHub Guild integration. One of `github_secret_id` / `existing_github_integration_name` must be provided."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration instead of provisioning one. When set, the module skips its own integration container."
  type        = string
  default     = ""
}

variable "stackgen_mcp_integration_name" {
  description = "Optional: Guild integration name for StackGen hosted MCP (SSE). Empty skips attaching StackGen MCP."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / workflow / runbook / integration resource names so multiple instances can coexist in one Guild tenant."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "agent_budget_usd_daily" {
  description = "Daily USD budget cap for the repository IaC architect agent."
  type        = number
  default     = 25
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

