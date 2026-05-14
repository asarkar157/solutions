variable "model_names" {
  description = <<-EOT
    Ordered list of registered model names exposed to this module's agents
    (highest preference first). Forwarded straight to `sg_agent.model_names`
    after `compact()`. Wire to `module.foundation.model_names` (a
    `list(string)` output) or to a hand-picked subset via
    `[module.foundation.model_names_by_provider.<key>]`.
  EOT
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Guardrail policy IDs. `dangerous_ops` is required for the cleanup workflow."
  type = object({
    dangerous_ops = string
  })
}

# =============================================================================
# Self-contained integration wiring.
# At least ONE of aws_secret_id / azure_secret_id / gcp_secret_id (or their
# existing_*_integration_name overrides) must be set — otherwise the agent has
# no surface to scan.
# =============================================================================

variable "aws_secret_id" {
  description = "Optional `sg_secret` ID for AWS credentials. When set, the module provisions an internal AWS Guild integration (Lambda + S3 + EBS + EIP / NAT / snapshot scans)."
  type        = string
  default     = ""
}

variable "azure_secret_id" {
  description = "Optional `sg_secret` ID for Azure credentials. When set, the module provisions an internal Azure Guild integration (managed disks / VMs / public IPs)."
  type        = string
  default     = ""
}

variable "gcp_secret_id" {
  description = "Optional `sg_secret` ID for GCP credentials. When set, the module provisions an internal GCP Guild integration (compute + persistent disks)."
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional `sg_secret` ID for Slack credentials. When set, the module provisions an internal Slack Guild integration for owner-grouped findings + cleanup notifications."
  type        = string
  default     = ""
}

variable "existing_aws_integration_name" {
  description = "Optional Guild integration name to share an existing AWS integration."
  type        = string
  default     = ""
}

variable "existing_azure_integration_name" {
  description = "Optional Guild integration name to share an existing Azure integration."
  type        = string
  default     = ""
}

variable "existing_gcp_integration_name" {
  description = "Optional Guild integration name to share an existing GCP integration."
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

variable "agent_budget" {
  description = "Daily $ budget for the resource-janitor agent."
  type        = number
  default     = 10
}

variable "inactivity_days" {
  description = "Threshold (in days) for treating a resource as unused. Inserted into runbook templates and into the workflow input defaults."
  type        = number
  default     = 30
}

variable "cleanup_dwell_days" {
  description = "Days a quarantined resource must remain tagged before the cleanup workflow is allowed to delete it."
  type        = number
  default     = 7
}

variable "max_resources_per_run" {
  description = "Hard cap on resources processed by a single cleanup execution; protects against runaway batches."
  type        = number
  default     = 25
}

variable "cleanup_dollar_cap" {
  description = "Stop the cleanup phase early once cumulative estimated monthly savings reach this number of USD."
  type        = number
  default     = 1000
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
