variable "app_name" {
  description = "Deployment-catalog application slug. StackGen SRE Copilot uses \"sre\"."
  type        = string
  default     = "sre"
}

variable "integration_names" {
  description = <<-EOT
    Guild integration names to add or ensure on the SRE app install (Datadog, AWS, GitHub, Grafana, etc.).
    When merge_existing_app_integrations is true (default), these are unioned with integrations already
    bound on the install (via data.sg_app). When false, this list replaces the full binding set on apply.
  EOT
  type        = list(string)
}

variable "merge_existing_app_integrations" {
  description = "When true, reads data.sg_app and unions integration_names with integrations already bound to the install (e.g. Datadog from SRE app onboarding). When false, integration_names replaces the full binding set."
  type        = bool
  default     = true
}

variable "config" {
  description = "Optional install metadata (e.g. setup_type = workspace). When null and enable_discovery_bootstrap is true, defaults to setup_type = workspace."
  type        = map(string)
  default     = null
}

variable "enable_discovery_bootstrap" {
  description = "When true, sets config setup_type = workspace on the SRE app install so onboarding can proceed. Run discovery from the SRE app UI (Discovery page) after apply. Provider sg_app.bootstrap_discovery (>= 0.1.27) may automate this in a future module revision."
  type        = bool
  default     = true
}

variable "alert_webhooks" {
  description = <<-EOT
    Alert ingest webhooks to register on the SRE app (Guild forwarder + classify settings).
    Each entry creates one sg_sre_alert_webhook. Use the bound integration instance name
    (e.g. datadog-integration), not the catalog type alone.
  EOT
  type = list(object({
    source                        = string
    integration                   = optional(string, "")
    auto_investigate              = optional(bool, false)
    classify_mode                 = optional(string, "batch")
    classify_batch_window_seconds = optional(number, 60)
    classify_bucket_by            = optional(string, "storm_scope")
    classify_critical_bypass      = optional(bool, true)
  }))
  default = []
}

variable "investigator_agent_name" {
  description = "Catalog SRE investigator agent to attach optional policies and remote runner (stackgen-sre-app manifest default)."
  type        = string
  default     = "stackgen-sre-investigator"
}

variable "investigator_policy_ids" {
  description = <<-EOT
    When non-null, attach listed policies to investigator_agent_name via sg_agent_policy_attachment.
    Pass policy_ids from module.aios-policies. Empty strings skip that attachment.
  EOT
  type = object({
    dangerous_ops                = optional(string, "")
    sre_remediation              = optional(string, "")
    prod_write_gate              = optional(string, "")
    sre_investigation_write_gate = optional(string, "")
    pagerduty_escalation_gate    = optional(string, "")
  })
  default = null
}

variable "policy_create_flags" {
  description = "Plan-time flags from module.aios-policies policy_create_flags output — gates optional policy attachments (dangerous_ops always attaches when ID is non-empty)."
  type = object({
    sre_remediation              = optional(bool, true)
    prod_write_gate              = optional(bool, true)
    sre_investigation_write_gate = optional(bool, true)
    pagerduty_escalation_gate    = optional(bool, true)
  })
  default = null
}

variable "remote_runner_name" {
  description = "When non-empty, adopt investigator_agent_name and merge this remote runner onto sg_agent.remote_runners (sre-boost pattern)."
  type        = string
  default     = ""
}
