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
    data_risk_pii          = optional(string, "")
    langfuse_observability = optional(string, "")
  })
}

# =============================================================================
# Self-contained integration wiring.
#
# Langfuse: no `aios-integration-langfuse` wrapper exists yet, so the only
# way to wire it in is via `existing_langfuse_integration_name` (required).
#
# Extras (grafana / slack / github): pass either a secret ID (this module
# provisions an internal integration) OR an existing integration name (this
# module attaches to it). Both forms are forwarded into the agent.
# =============================================================================

variable "existing_langfuse_integration_name" {
  description = "Guild integration name for an externally-provisioned Langfuse integration. Required — no aios-integration-langfuse wrapper exists."
  type        = string

  validation {
    condition     = trimspace(var.existing_langfuse_integration_name) != ""
    error_message = "existing_langfuse_integration_name is required."
  }
}

variable "grafana_secret_id" {
  description = "Optional `sg_secret` ID for Grafana. When set, the module provisions an internal Grafana Guild integration for infra correlation."
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional `sg_secret` ID for Slack. When set, the module provisions an internal Slack Guild integration for digest posting."
  type        = string
  default     = ""
}

variable "github_secret_id" {
  description = "Optional `sg_secret` ID for GitHub. When set, the module provisions an internal GitHub Guild integration for deploy context."
  type        = string
  default     = ""
}

variable "existing_grafana_integration_name" {
  description = "Optional Guild integration name to share an existing Grafana integration."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional Guild integration name to share an existing Slack integration."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration."
  type        = string
  default     = ""
}

variable "extra_integration_names" {
  description = "Optional list of additional pre-existing Guild integration names (linear, aws, gcp, clickhouse, etc.) to attach to the observer agent."
  type        = list(string)
  default     = []
}

variable "name_suffix" {
  description = "Optional suffix appended to integration resource names provisioned by this module."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "agent_name" {
  description = "sg_agent name. Override when deploying multiple observers (e.g. per team or Langfuse project)."
  type        = string
  default     = "langfuse-ai-quality-observer"
}

variable "workflow_name" {
  description = "sg_workflow name for the AI Ops Health Scorecard."
  type        = string
  default     = "ai-ops-health-scorecard"
}

variable "workflow_domain" {
  type    = string
  default = "observability"
}

variable "runbook_name_prefix" {
  description = "Prefix for sg_runbook_sop resource names to avoid collisions when this module is instantiated more than once in the same StackGen project."
  type        = string
  default     = "langfuse"
}

variable "additional_example_queries" {
  description = "Extra example_queries appended to the workflow (e.g. team-specific scorecard prompts)."
  type        = list(string)
  default     = []
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow_name>::<stage_id>" where workflow_name matches var.workflow_name and stage_id matches the stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}

variable "agent_budget" {
  type    = number
  default = 10
}
