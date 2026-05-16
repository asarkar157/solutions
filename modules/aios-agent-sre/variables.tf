variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Policy IDs from the policies module for agent policy attachments"
  type = object({
    dangerous_ops            = string
    sre_remediation          = optional(string, "")
    prod_write_gate          = optional(string, "")
    tier0_service_protection = optional(string, "")
    blast_radius_limit       = optional(string, "")
    freeze_window            = optional(string, "")
    data_risk_pii            = optional(string, "")
    post_action_verification = optional(string, "")
  })
}

variable "policy_create_flags" {
  description = "Must align with module.policies policy_create_flags (same semantics as create_policies). Used only for Terraform count on optional attachments — avoids unknown counts when policy IDs are (known after apply). An attachment is created only when the matching flag is true and the corresponding policy_ids field is non-empty."
  type = object({
    sre_remediation          = optional(bool, true)
    prod_write_gate          = optional(bool, true)
    tier0_service_protection = optional(bool, true)
    blast_radius_limit       = optional(bool, true)
    freeze_window            = optional(bool, true)
    data_risk_pii            = optional(bool, true)
    post_action_verification = optional(bool, true)
  })
  default = {}
}

# =============================================================================
# Self-contained integration wiring (replaces the old `integration_names` map).
# =============================================================================

variable "grafana_secret_id" {
  description = "Optional `sg_secret` ID for Grafana. When set, this module provisions an internal Grafana Guild integration so triage / incident agents can query metrics/logs."
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional `sg_secret` ID for Slack workspace credentials. When set, this module provisions an internal Slack Guild integration so the incident commander can post status updates."
  type        = string
  default     = ""
}

variable "linear_credential_provider_id" {
  description = "Optional OAuth credential provider ID (see StackGen Vault) for Linear. When set, this module provisions an internal Linear Guild integration so the incident commander can file follow-up tickets."
  type        = string
  default     = ""
}

variable "existing_grafana_integration_name" {
  description = "Optional Guild integration name to share an existing Grafana integration instead of provisioning one."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional Guild integration name to share an existing Slack integration."
  type        = string
  default     = ""
}

variable "existing_linear_integration_name" {
  description = "Optional Guild integration name to share an existing Linear integration."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / workflow / runbook / integration resource names so multiple instances can coexist in one Guild tenant."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "agent_budgets" {
  description = "Daily budget limits (USD) per agent"
  type = object({
    auto_remediation   = optional(number, 25)
    incident           = optional(number, 25)
    triage             = optional(number, 15)
    change_correlation = optional(number, 15)
    risk_posture       = optional(number, 15)
  })
  default = {}
}

variable "incident_notification_webhook_url" {
  description = <<-EOT
    Optional HTTP(S) URL for deterministic stakeholder notifications.
    When non-empty, the incident-response workflow includes `notify-stakeholders`
    and exposes it in `triage-navigation-gate` allowed transitions. When empty, that
    webhook stage is omitted and the gate only routes back to correlate-changes or forward
    to remediation planning.
    The stage POSTs the severity and blast-radius summary as JSON — zero LLM cost,
    sub-second latency. Typical targets: Slack incoming webhook, OpsGenie, PagerDuty
    Events API v2, or any HTTP endpoint that accepts JSON.
  EOT
  type        = string
  default     = ""
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow_name>::<stage_id>" using each sg_workflow.name (e.g. incident-response::collect-signals) and the stage_id string.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}

