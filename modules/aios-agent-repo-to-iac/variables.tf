variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Policy IDs from aios-policies (typically dangerous_ops)"
  type = object({
    dangerous_ops = string
  })
}

variable "github_integration_name" {
  description = "Guild integration name for the GitHub MCP integration (from aios-integration-github)."
  type        = string
}

variable "stackgen_mcp_integration_name" {
  description = "Optional: Guild integration name for StackGen hosted MCP (SSE). Empty skips attaching StackGen MCP."
  type        = string
  default     = ""
}

variable "agent_budget_usd_daily" {
  description = "Daily USD budget cap for the repository IaC architect agent."
  type        = number
  default     = 25
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

