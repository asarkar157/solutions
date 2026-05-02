variable "agent_name" {
  description = "Guild agent name (must match an existing sg_agent.name from another module)."
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
