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
    dangerous_ops = string
    data_risk_pii = optional(string, "")
  })
}

variable "policy_create_flags" {
  description = <<-EOT
    Align with module.policies.policy_create_flags for optional attachments. Drives Terraform count
    on the data_risk_pii attachment so count does not depend on unknown policy_ids. Set data_risk_pii
    to true when you pass module.policies.policy_ids.data_risk_pii from the same stack.
  EOT
  type = object({
    data_risk_pii = optional(bool, false)
  })
  default = {}
}

# =============================================================================
# Self-contained integration wiring.
# =============================================================================

variable "aws_secret_id" {
  description = "Optional `sg_secret` ID for AWS credentials. When set, the module provisions an internal AWS Guild integration so the auditor can pull IAM / Config evidence."
  type        = string
  default     = ""
}

variable "github_secret_id" {
  description = "Optional `sg_secret` ID for a GitHub PAT. When set, the module provisions an internal GitHub Guild integration for change-management evidence review."
  type        = string
  default     = ""
}

variable "existing_aws_integration_name" {
  description = "Optional Guild integration name to share an existing AWS integration."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration."
  type        = string
  default     = ""
}

variable "enable_cce" {
  description = "When true and GitHub is wired, provisions Ubuntu + CCE for audit-evidence and regulatory-scope repo scans."
  type        = bool
  default     = true
}

variable "existing_ubuntu_integration_name" {
  description = "Optional Guild integration name to share an existing Ubuntu CLI integration for CCE scans."
  type        = string
  default     = ""
}

variable "cce_use_case" {
  description = "Default CCE usage lens for compliance repo scans (see appcd-dev/cce docs/usages)."
  type        = string
  default     = "audit-evidence"
}

variable "enable_compliance_evidence_factory" {
  description = "When true (requires enable_cce), provisions compliance-evidence-factory workflow for multi-repo CCE pack scans."
  type        = bool
  default     = false
}

variable "audit_repo_list" {
  description = "GitHub repo slugs (org/repo) for compliance evidence factory multi-repo CCE scans."
  type        = list(string)
  default     = []
}

variable "compliance_evidence_schedule_cron" {
  description = "Optional cron expression hint for aios-agent-schedules companion (documented in README)."
  type        = string
  default     = "0 9 1 */3 *"
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

variable "agent_budget" {
  type    = number
  default = 20
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

