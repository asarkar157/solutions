variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}
variable "policy_ids" {
  type = object({ dangerous_ops = string })
}
variable "integration_names" {
  type    = map(string)
  default = {}
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

