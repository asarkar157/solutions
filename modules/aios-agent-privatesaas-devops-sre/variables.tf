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

variable "grafana_server" {
  description = "Private Grafana server URL (e.g. https://grafana.internal.example.com). Used when provisioning an internal Grafana integration."
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

variable "paloalto_management_url" {
  description = "PAN-OS management URL when provisioning an internal Palo Alto integration."
  type        = string
  default     = ""
}

variable "paloalto_api_key" {
  description = "PAN-OS XML API key (preferred) when provisioning an internal Palo Alto integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "paloalto_username" {
  description = "Optional PAN-OS username when API key auth is insufficient."
  type        = string
  default     = ""
}

variable "paloalto_password" {
  description = "Optional PAN-OS password paired with `paloalto_username`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "paloalto_secret_id" {
  description = "Optional existing `sg_secret` ID for Palo Alto credentials."
  type        = string
  default     = ""
}

variable "existing_paloalto_integration_name" {
  description = "Optional Guild integration name to share an existing Palo Alto integration."
  type        = string
  default     = ""
}

variable "paloalto_integration_type" {
  description = "Guild integration `type` for the internal Palo Alto submodule. Confirm against your Guild catalog."
  type        = string
  default     = "paloalto"
}

# =============================================================================
# PrivateSaaS context
# =============================================================================

variable "private_saas_environment_label" {
  description = "Human-readable label for the PrivateSaaS environment (e.g. prod-vpc-us-east-1) injected into runbooks and workflow descriptions."
  type        = string
  default     = "privatesaas"
}

variable "paloalto_vsys" {
  description = "Default PAN-OS virtual system (vsys) hint for firewall log and policy queries."
  type        = string
  default     = "vsys1"
}

variable "paloalto_device_group_hints" {
  description = "List of PAN-OS device group name hints for policy review and log scoping."
  type        = list(string)
  default     = []
}

# =============================================================================
# Alert ingest filtering (deterministic policy_check at workflow ingress)
# =============================================================================

variable "alert_ingest_allowed_severities" {
  description = "Grafana alert severities allowed through the ingest filter (case-insensitive, e.g. warning, critical, p2, sev2). Empty list skips the severity gate."
  type        = list(string)
  default     = ["warning", "critical", "p2", "p3", "p4", "sev2", "sev3", "sev4"]
}

variable "alert_ingest_allowed_environments" {
  description = "Environment labels required when non-empty (e.g. production, staging). Empty list skips the environment gate."
  type        = list(string)
  default     = []
}

variable "alert_ingest_allowed_namespaces" {
  description = "Kubernetes/application namespace labels required when non-empty. Empty list skips the namespace gate."
  type        = list(string)
  default     = []
}

variable "alert_ingest_blocked_alert_names" {
  description = "Alert names rejected at ingest (case-insensitive substring match on payload text)."
  type        = list(string)
  default     = []
}

# =============================================================================
# Webhook ingress
# =============================================================================

variable "enable_grafana_webhook" {
  description = "When true, creates sg_webhook targeting privatesaas-incident-response for Grafana alert ingress."
  type        = bool
  default     = true
}

variable "webhook_allowed_cidrs" {
  description = "Optional CIDR allowlist for the Grafana ingress webhook."
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
    alert_ingest = optional(number, 10)
    investigator = optional(number, 25)
    remediator   = optional(number, 25)
  })
  default = {}
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow-name>::<stage_id>" where stage_id matches the workflow stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}
