variable "target_type" {
  description = "Guild schedule target: agent (sg_agent.name) or workflow (sg_workflow.name). Same semantics as sg_webhook."
  type        = string
  default     = "agent"

  validation {
    condition     = contains(["agent", "workflow"], var.target_type)
    error_message = "target_type must be \"agent\" or \"workflow\"."
  }
}

variable "target_name" {
  description = "Name of the agent or workflow this cron schedule invokes (must match an existing sg_agent or sg_workflow)."
  type        = string
}

variable "schedules" {
  description = <<-EOT
    Recurring cron prompts for this agent. Each entry becomes one sg_agent_schedule.
    Use stable unique `name` values (lowercase letters, digits, hyphens; Terraform keys must be unique).
    `expression` is a five-field cron (e.g. "0 9 * * *" for 09:00 UTC daily).
    `action` is the user-visible prompt sent to the agent when the schedule fires.
  EOT
  type = list(object({
    name       = string
    expression = string
    action     = string
    enabled    = optional(bool)
  }))
  default = []

  validation {
    condition     = length(distinct([for s in var.schedules : s.name])) == length(var.schedules)
    error_message = "Each schedule must have a unique `name`."
  }
}
