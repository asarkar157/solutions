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
  description = "Map of models available to use"
  type        = map(string)
}

variable "policy_ids" {
  type    = map(string)
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
