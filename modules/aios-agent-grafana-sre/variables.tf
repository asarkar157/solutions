variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}
variable "policy_ids" {
  type = object({ dangerous_ops = string, data_risk_pii = optional(string, "") })
}

# =============================================================================
# Self-contained integration wiring (replaces the old per-module Grafana secret +
# integration creation).
# =============================================================================

variable "grafana_secret_id" {
  description = "**Required.** ID of an `sg_secret` (`Observability`/`grafana`) holding the Grafana base URL + service-account token. Forward [`aios-integration-grafana`](../aios-integration-grafana).secret_id or an existing Grafana-shaped secret."
  type        = string
}

variable "existing_grafana_integration_name" {
  description = "Optional Guild integration name to share an existing Grafana integration instead of provisioning one."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / runbook / integration resource names so multiple instances can coexist in one Guild tenant."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "agent_budget" {
  type    = number
  default = 15
}
