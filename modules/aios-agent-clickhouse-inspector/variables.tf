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
  type = object({
    dangerous_ops         = string
    data_risk_pii         = optional(string, "")
    azure_tool_governance = optional(string, "")
  })
}
# =============================================================================
# Self-contained integration wiring.
# =============================================================================

variable "clickhouse_secret_id" {
  description = "Optional `sg_secret` ID for ClickHouse credentials. When set, the module provisions an internal ClickHouse Guild integration. Required unless `existing_clickhouse_integration_name` is set."
  type        = string
  default     = ""
}

variable "clickhouse_mcp_image" {
  description = "User-provided container image running the MCP server for ClickHouse. Only used when this module provisions its own integration."
  type        = string
  default     = ""
}

variable "existing_clickhouse_integration_name" {
  description = "Optional Guild integration name to share an existing ClickHouse integration. When set, no internal integration is provisioned."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / workflow / runbook / integration resource names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}
