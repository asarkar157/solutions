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
  description = "Policy IDs from module.policies for agent guardrails."
  type = object({
    dangerous_ops   = string
    sre_remediation = optional(string, "")
    prod_write_gate = optional(string, "")
  })
}

variable "policy_create_flags" {
  description = "Plan-time flags aligned with module.policies.policy_create_flags. Drives count on optional sg_agent_policy_attachment resources."
  type = object({
    sre_remediation = optional(bool, true)
    prod_write_gate = optional(bool, true)
  })
  default = {}
}

# =============================================================================
# Self-contained integration wiring
# =============================================================================

variable "servicenow_instance_url" {
  description = "ServiceNow instance URL when provisioning an internal ServiceNow integration."
  type        = string
  default     = ""
}

variable "servicenow_username" {
  description = "ServiceNow username when provisioning an internal ServiceNow integration."
  type        = string
  default     = ""
}

variable "servicenow_password" {
  description = "ServiceNow password when provisioning an internal ServiceNow integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "servicenow_secret_id" {
  description = "Optional existing `sg_secret` ID for ServiceNow credentials."
  type        = string
  default     = ""
}

variable "existing_servicenow_integration_name" {
  description = "Optional Guild integration name to share an existing ServiceNow integration."
  type        = string
  default     = ""
}

variable "aws_secret_id" {
  description = "Optional `sg_secret` ID for AWS credentials. When set (and `existing_aws_integration_name` is empty), the module provisions an internal AWS Guild integration."
  type        = string
  default     = ""
}

variable "existing_aws_integration_name" {
  description = "Optional Guild integration name to share an existing AWS integration instead of provisioning one."
  type        = string
  default     = ""
}

variable "grafana_server" {
  description = "Grafana base URL when provisioning an internal Grafana integration."
  type        = string
  default     = ""
}

variable "grafana_token" {
  description = "Grafana service account token when provisioning an internal Grafana integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_secret_id" {
  description = "Optional existing `sg_secret` ID for Grafana credentials."
  type        = string
  default     = ""
}

variable "existing_grafana_integration_name" {
  description = "Optional Guild integration name to share an existing Grafana integration."
  type        = string
  default     = ""
}

variable "slack_bot_token" {
  description = "Slack bot token when provisioning an internal Slack integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_signing_secret" {
  description = "Slack signing secret when provisioning an internal Slack integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_url" {
  description = "Optional Slack incoming webhook URL when provisioning an internal Slack integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional existing `sg_secret` ID for Slack credentials."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional Guild integration name to share an existing Slack integration."
  type        = string
  default     = ""
}

variable "slack_channel_hint" {
  description = "Optional Slack channel name or ID hint injected into resolution runbook context (e.g. #sre-incidents or C01234567)."
  type        = string
  default     = ""
}

# =============================================================================
# Ticket ingest filtering (deterministic policy_check at workflow ingress)
# =============================================================================

variable "ticket_ingest_allowed_priorities" {
  description = "ServiceNow priorities allowed through the ingest filter (case-insensitive, e.g. p2, p3, 3 - moderate). Empty list skips the priority gate."
  type        = list(string)
  default     = ["p2", "p3", "p4", "p5", "3 - moderate", "4 - low"]
}

variable "ticket_ingest_allowed_assignment_groups" {
  description = "Assignment group names allowed through ingest when non-empty. Empty list skips the assignment group allowlist gate."
  type        = list(string)
  default     = []
}

variable "ticket_ingest_allowed_categories" {
  description = "Ticket categories allowed through ingest when non-empty. Empty list skips the category allowlist gate."
  type        = list(string)
  default     = []
}

variable "ticket_ingest_blocked_assignment_groups" {
  description = "Assignment group names rejected at ingest (case-insensitive substring match on payload text)."
  type        = list(string)
  default     = []
}

variable "ticket_ingest_blocked_short_description_substrings" {
  description = "Short description substrings that cause ingest to drop the ticket (case-insensitive)."
  type        = list(string)
  default     = []
}

# =============================================================================
# Webhook ingress
# =============================================================================

variable "enable_servicenow_webhook" {
  description = "When true, creates sg_webhook `servicenow-ticket-receiver` targeting servicenow-ticket-resolution for ServiceNow ingress."
  type        = bool
  default     = true
}

variable "webhook_allowed_cidrs" {
  description = "Optional CIDR allowlist for the ServiceNow ingress webhook."
  type        = list(string)
  default     = []
}

variable "webhook_trigger_base_url" {
  description = <<-EOT
    Optional StackGen HTTP API origin (e.g. `https://main.dev.stackgen.com`). When set,
    outputs include `webhook_trigger_endpoint` and, when the ingress webhook token exists,
    `webhook_ingress_payload_url` for senders that cannot set `Authorization: Bearer`.
  EOT
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = "Optional `orgId` query parameter appended to `webhook_ingress_payload_url` when `webhook_trigger_base_url` is set."
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

variable "agent_budgets" {
  description = "Daily budget limits (USD) per agent."
  type = object({
    intake       = optional(number, 10)
    investigator = optional(number, 25)
    resolver     = optional(number, 25)
  })
  default = {}
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "servicenow-ticket-resolution::<stage_id>" where stage_id matches the workflow stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}
