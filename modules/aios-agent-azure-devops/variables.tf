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

