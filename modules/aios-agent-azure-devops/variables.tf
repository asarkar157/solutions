variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
}
variable "policy_ids" {
  type = object({
    dangerous_ops        = string
    prod_write_gate      = optional(string, "")
    sre_remediation      = optional(string, "")
    container_shell_hitl = optional(string, "")
  })
}
variable "integration_names" {
  type    = map(string)
  default = {}
}
variable "azure_readonly_tools" {
  type    = list(string)
  default = []
}
variable "clickhouse_inspector_agent_name" {
  type    = string
  default = ""
}
variable "agent_budget" {
  type    = number
  default = 20
}

variable "secret_names" {
  type    = map(string)
  default = {}
}

variable "reader_principal_id" {
  type    = string
  default = ""
}

variable "azure_role_scope" {
  type    = string
  default = ""
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

