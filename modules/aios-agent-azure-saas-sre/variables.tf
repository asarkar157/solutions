variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

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

variable "datadog_api_key" {
  description = "Datadog API key. Used with `datadog_app_key` when provisioning an internal Datadog integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_app_key" {
  description = "Datadog application key paired with `datadog_api_key`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_site" {
  description = "Datadog site hostname (e.g. datadoghq.com, datadoghq.eu)."
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_secret_id" {
  description = "Optional existing `sg_secret` ID for Datadog MCP credentials."
  type        = string
  default     = ""
}

variable "existing_datadog_integration_name" {
  description = "Optional Guild integration name to share an existing Datadog integration."
  type        = string
  default     = ""
}

variable "pagerduty_api_token" {
  description = "PagerDuty REST API token when provisioning an internal PagerDuty integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "pagerduty_secret_id" {
  description = "Optional existing `sg_secret` ID for PagerDuty credentials."
  type        = string
  default     = ""
}

variable "existing_pagerduty_integration_name" {
  description = "Optional Guild integration name to share an existing PagerDuty integration."
  type        = string
  default     = ""
}

variable "confluence_base_url" {
  description = "Confluence Cloud base URL (e.g. https://yourorg.atlassian.net/wiki)."
  type        = string
  default     = ""
}

variable "confluence_email" {
  description = "Atlassian account email for Confluence API token auth."
  type        = string
  default     = ""
}

variable "confluence_api_token" {
  description = "Confluence API token when provisioning an internal Confluence integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "confluence_secret_id" {
  description = "Optional existing `sg_secret` ID for Confluence credentials."
  type        = string
  default     = ""
}

variable "existing_confluence_integration_name" {
  description = "Optional Guild integration name to share an existing Confluence integration."
  type        = string
  default     = ""
}

variable "confluence_space_key" {
  description = "Confluence space key where operational runbooks live (e.g. SRE, OPS)."
  type        = string
}

variable "azure_secret_id" {
  description = "Optional `sg_secret` ID for Azure credentials. When set (and `existing_azure_integration_name` is empty), the module provisions an internal Azure Guild integration."
  type        = string
  default     = ""
}

variable "existing_azure_integration_name" {
  description = "Optional Guild integration name to share an existing Azure integration instead of provisioning one."
  type        = string
  default     = ""
}

# =============================================================================
# Alert ingest filtering (deterministic policy_check at workflow ingress)
# =============================================================================

variable "alert_ingest_allowed_priorities" {
  description = "PagerDuty priorities/urgencies allowed through the ingest filter (case-insensitive, e.g. p2, p3, sev2). Empty list skips the priority gate."
  type        = list(string)
  default     = ["p2", "p3", "p4", "p5"]
}

variable "alert_ingest_allowed_services" {
  description = "Service names allowed through ingest when non-empty. Empty list skips the service allowlist gate."
  type        = list(string)
  default     = []
}

variable "alert_ingest_blocked_services" {
  description = "Service names rejected at ingest (case-insensitive substring match on payload text)."
  type        = list(string)
  default     = []
}

variable "alert_ingest_allowed_environments" {
  description = "Environment labels required when non-empty (e.g. production, prod-eu). Empty list skips the environment gate."
  type        = list(string)
  default     = []
}

# =============================================================================
# Azure Automation remediation hints
# =============================================================================

variable "azure_automation_account_name" {
  description = "Azure Automation account name used when starting runbooks for remediation."
  type        = string
  default     = ""
}

variable "azure_automation_resource_group" {
  description = "Resource group containing the Azure Automation account."
  type        = string
  default     = ""
}

variable "azure_automation_subscription_id" {
  description = "Optional subscription ID hint for Azure CLI runbook invocations."
  type        = string
  default     = ""
}

variable "azure_automation_runbook_name_hints" {
  description = "Map of alert keyword or service slug to Azure Automation runbook name hints for Confluence cross-reference."
  type        = map(string)
  default     = {}
}

# =============================================================================
# Webhook ingress
# =============================================================================

variable "enable_pagerduty_webhook" {
  description = "When true, creates sg_webhook targeting pagerduty-saas-incident-response for PagerDuty Events/v3 ingress."
  type        = bool
  default     = true
}

variable "webhook_allowed_cidrs" {
  description = "Optional CIDR allowlist for the PagerDuty ingress webhook."
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
    Keys: "pagerduty-saas-incident-response::<stage_id>" where stage_id matches the workflow stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}
