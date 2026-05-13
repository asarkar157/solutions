variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
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
