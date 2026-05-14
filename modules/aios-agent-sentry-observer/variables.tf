variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Policy IDs from the root module for agent policy attachments"
  type = object({
    dangerous_ops        = string
    data_risk_pii        = string
    sentry_observability = string
  })
}

# =============================================================================
# Integration wiring. No `aios-integration-sentry` module exists yet, so the
# only way to wire Sentry in is via `existing_sentry_integration_name`.
# =============================================================================

variable "existing_sentry_integration_name" {
  description = "Guild integration name for an externally-provisioned Sentry integration. Required — no aios-integration-sentry wrapper exists."
  type        = string

  validation {
    condition     = trimspace(var.existing_sentry_integration_name) != ""
    error_message = "existing_sentry_integration_name is required: pass the name of a pre-provisioned Sentry Guild integration."
  }
}

variable "name_suffix" {
  description = "Optional suffix appended to agent resource names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}
