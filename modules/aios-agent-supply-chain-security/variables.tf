variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  type = object({ dangerous_ops = string, sre_remediation = optional(string, "") })
}

# =============================================================================
# Self-contained integration wiring (replaces the old `github_integration_name`
# + raw `github_token` inputs).
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

variable "enable_cce" {
  description = "When true and GitHub is wired, provisions Ubuntu + CCE for CVE reachability analysis."
  type        = bool
  default     = true
}

variable "enable_cce_reachability" {
  description = "When true (requires enable_cce), runs cve-reachability lens and fix-PR stages."
  type        = bool
  default     = true
}

variable "existing_ubuntu_integration_name" {
  description = "Optional Guild integration name to share an existing Ubuntu CLI integration for CCE scans."
  type        = string
  default     = ""
}

variable "cve_allowlist" {
  description = "Optional CVE IDs to skip even when CCE reports reachability."
  type        = list(string)
  default     = []
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / workflow / runbook / policy / integration resource names so multiple instances can coexist in one Guild tenant."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "agent_budget" {
  type    = number
  default = 15
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow_name>::<stage_id>" where workflow_name is the sg_workflow.name in this module and stage_id matches the stage.
    Each value is appended after the module defaults for that stage (defaults are this module's sg_runbook_sop names so load_skill resolves via runbook fallback when no registry skill exists).
  EOT
  type        = map(list(string))
  default     = {}
}
