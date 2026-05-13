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

variable "integration_names" {
  description = <<-EOT
    Map of cloud / notification integrations to attach to the resource-janitor agent.
    Recognized keys (all optional except aws):
      - aws    : AWS integration name (required for Lambda + S3 + EBS scans)
      - azure  : Azure integration name (extends scans to managed disks / VMs / public IPs)
      - gcp    : GCP integration name (extends scans to compute and persistent disks)
      - slack  : Slack integration name for owner-grouped findings + cleanup notifications
  EOT
  type        = map(string)
  default     = {}
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
