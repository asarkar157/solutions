variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string })
}
variable "policy_ids" {
  type = object({
    dangerous_ops         = string
    data_risk_pii         = optional(string, "")
    azure_tool_governance = optional(string, "")
  })
}
variable "integration_names" {
  type = object({ clickhouse = string })
}
