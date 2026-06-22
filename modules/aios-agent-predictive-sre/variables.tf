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
  type = object({ dangerous_ops = string })
}
# =============================================================================
# Self-contained integration wiring.
# =============================================================================

variable "github_secret_id" {
  description = "Optional `sg_secret` ID for the GitHub PAT. When set, the module provisions an internal GitHub Guild integration so the predictive analyst can pull PR / deploy context."
  type        = string
  default     = ""
}

variable "grafana_secret_id" {
  description = "Optional `sg_secret` ID for Grafana. When set, the module provisions an internal Grafana Guild integration."
  type        = string
  default     = ""
}

variable "aws_secret_id" {
  description = "Optional `sg_secret` ID for AWS credentials. When set, the module provisions an internal AWS Guild integration."
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional `sg_secret` ID for Slack credentials. When set, the module provisions an internal Slack Guild integration."
  type        = string
  default     = ""
}

variable "enable_cce" {
  description = "When true and GitHub is wired, provisions Ubuntu + CCE for change-impact analysis on default repos."
  type        = bool
  default     = true
}

variable "existing_ubuntu_integration_name" {
  description = "Optional Guild integration name to share an existing Ubuntu CLI integration."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration."
  type        = string
  default     = ""
}

variable "existing_grafana_integration_name" {
  description = "Optional Guild integration name to share an existing Grafana integration."
  type        = string
  default     = ""
}

variable "existing_aws_integration_name" {
  description = "Optional Guild integration name to share an existing AWS integration."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional Guild integration name to share an existing Slack integration."
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
variable "agent_names" {
  description = "External agent names for cross-domain workflow stage bindings"
  type = object({
    github_agent  = string
    grafana_agent = string
    aws_agent     = string
  })
}
variable "agent_budget" {
  type    = number
  default = 25
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

