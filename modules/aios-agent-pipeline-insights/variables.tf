variable "model_names" {
  description = <<-EOT
    Ordered list of registered model names to expose to the agent (highest
    preference first). Forwarded straight to `sg_agent.model_names` after
    `compact()`.
  EOT
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Guardrail policy IDs. `dangerous_ops` is required."
  type = object({
    dangerous_ops = string
  })
}

variable "integration_names" {
  description = <<-EOT
    Map of integrations to attach to the pipeline-insights agent.
    Recognized keys (`github` is required; others optional):
      - github : GitHub integration name (REST/GraphQL access for Actions, PRs, Deployments)
      - slack  : Slack integration name (used by the Slack ingress webhook + replies)
  EOT
  type        = map(string)
}

variable "agent_budget" {
  description = "Daily $ budget for the pipeline-insights agent."
  type        = number
  default     = 8
}

variable "deployments_limit" {
  description = "Default number of recent deployments returned per environment when the operator does not supply a limit."
  type        = number
  default     = 10
}

variable "enable_slack_webhook" {
  description = <<-EOT
    Create an `sg_webhook` ingress (`target_type = workflow`) so a Slack app or
    other Slack-mention bridge can fire the pipeline-insights workflow with a
    raw question. Set to false if you only want to invoke the workflow from
    Guild chat or `aios-agent-schedules`.
  EOT
  type        = bool
  default     = false
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
