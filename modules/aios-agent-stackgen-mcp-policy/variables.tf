variable "stackgen_mcp_url" {
  description = "StackGen MCP endpoint URL. Paths containing /mcp/sse set Vault transport to sse; otherwise streamable_http (e.g. https://HOST/api/mcp/user)."
  type        = string
  default     = "https://main.dev.stackgen.com/api/mcp/sse"
}

variable "stackgen_api_token" {
  description = "The authentication token for StackGen MCP"
  type        = string
  sensitive   = true
}

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
  type    = map(string)
  default = {}
}

variable "policy_create_flags" {
  description = "Plan-time flags aligned with module.policies.policy_create_flags. Drives count on optional dangerous_ops attachment (policy ID is often unknown until apply)."
  type = object({
    dangerous_ops = optional(bool, true)
  })
  default = {}
}

variable "integration_names" {
  type    = map(string)
  default = {}
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
