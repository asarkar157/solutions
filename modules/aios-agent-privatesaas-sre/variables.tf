variable "model_names" {
  description = "Ordered list of Guild-registered model names (highest preference first). Register Bifrost in `aios-foundation` as an OpenAI-compatible provider and pass the resulting model name(s) here, or use `bifrost_model_names` to override."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "bifrost_model_names" {
  description = "Optional override of `model_names` when the customer routes all agent LLM traffic through a Bifrost OpenAI-compatible gateway registered in `aios-foundation` (see module README). When non-empty, this list is used instead of `model_names` on all agents."
  type        = list(string)
  default     = []
}

variable "bifrost_gateway_url" {
  description = "Documentation-only hint for the customer Bifrost gateway URL (e.g. https://bifrost.internal.example.com/v1). Not used as a Terraform resource; injected into workflow description templates when set."
  type        = string
  default     = ""
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
  description = "Plan-time flags aligned with module.policies.policy_create_flags."
  type = object({
    sre_remediation = optional(bool, true)
    prod_write_gate = optional(bool, true)
  })
  default = {}
}

# =============================================================================
# Integration wiring
# =============================================================================

variable "grafana_server" {
  description = "Private Grafana server URL when provisioning an internal Grafana integration."
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
  description = "Optional Guild integration name for an existing Grafana integration."
  type        = string
  default     = ""
}

variable "gcp_credentials_json" {
  description = "GCP service account JSON when provisioning a GCP integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "gcp_project_id" {
  description = "GCP project ID for investigation runbooks and secret metadata."
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP region hint for investigation runbooks."
  type        = string
  default     = "us-central1"
}

variable "gcp_secret_id" {
  description = "Optional existing `sg_secret` ID for GCP credentials."
  type        = string
  default     = ""
}

variable "existing_gcp_integration_name" {
  description = "Optional Guild integration name for an existing GCP integration."
  type        = string
  default     = ""
}

variable "firehydrant_api_key" {
  description = "FireHydrant API token when provisioning a FireHydrant integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "firehydrant_base_url" {
  description = "FireHydrant API base URL (defaults to https://api.firehydrant.io in the integration submodule)."
  type        = string
  default     = ""
}

variable "firehydrant_secret_id" {
  description = "Optional existing `sg_secret` ID for FireHydrant credentials."
  type        = string
  default     = ""
}

variable "existing_firehydrant_integration_name" {
  description = "Optional Guild integration name for an existing FireHydrant integration."
  type        = string
  default     = ""
}

variable "internal_tool_base_url" {
  description = "Internal operator console / service catalog API base URL when provisioning the internal tooling integration."
  type        = string
  default     = ""
}

variable "internal_tool_api_key" {
  description = "Optional bearer token for the internal REST API."
  type        = string
  sensitive   = true
  default     = ""
}

variable "internal_tool_secret_id" {
  description = "Optional existing `sg_secret` ID for internal tooling REST credentials (`base_url`, optional `auth_header`)."
  type        = string
  default     = ""
}

variable "existing_internal_tool_integration_name" {
  description = "Optional Guild integration name for an existing internal tooling (`restapi`) integration."
  type        = string
  default     = ""
}

# =============================================================================
# Runbook catalog
# =============================================================================

variable "external_runbook_catalog" {
  description = "Operator-supplied runbook catalog (name → url and description) rendered into investigator and runbook-coordinator templates (Confluence exports, Git-backed SOPs, wiki links)."
  type = map(object({
    url         = string
    description = optional(string, "")
  }))
  default = {}
}

# =============================================================================
# PrivateSaaS context
# =============================================================================

variable "private_saas_environment_label" {
  description = "Human-readable PrivateSaaS environment label injected into runbooks and workflows."
  type        = string
  default     = "privatesaas"
}

# =============================================================================
# Incident ingest filtering
# =============================================================================

variable "incident_ingest_allowed_severities" {
  description = "Severities allowed through the ingest filter (case-insensitive). Empty list skips the gate."
  type        = list(string)
  default     = ["warning", "critical", "p2", "p3", "p4", "sev2", "sev3", "sev4"]
}

variable "incident_ingest_allowed_services" {
  description = "Service names required when non-empty (substring match on payload). Empty list skips the gate."
  type        = list(string)
  default     = []
}

variable "incident_ingest_allowed_environments" {
  description = "Environment labels required when non-empty. Empty list skips the gate."
  type        = list(string)
  default     = []
}

variable "incident_ingest_blocked_services" {
  description = "Service names rejected at ingest (case-insensitive substring match)."
  type        = list(string)
  default     = []
}

# =============================================================================
# Webhooks and module options
# =============================================================================

variable "enable_grafana_webhook" {
  description = "When true, creates `sg_webhook` targeting `privatesaas-incident-response` for Grafana alert ingress."
  type        = bool
  default     = true
}

variable "enable_firehydrant_webhook" {
  description = "When true, creates `sg_webhook` targeting `privatesaas-incident-response` for FireHydrant incident ingress."
  type        = bool
  default     = false
}

variable "enable_evidence_checklist" {
  description = "When true, attaches an evidence checklist to the incident response workflow."
  type        = bool
  default     = false
}

variable "webhook_allowed_cidrs" {
  description = "Optional CIDR allowlist for ingress webhooks."
  type        = list(string)
  default     = []
}

variable "webhook_trigger_base_url" {
  description = "Optional StackGen HTTP API origin for webhook ingress URL outputs."
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = "Optional `orgId` query parameter for `webhook_ingress_payload_url`."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent, workflow, runbook, and integration names."
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
    incident_ingest     = optional(number, 10)
    investigator        = optional(number, 30)
    runbook_coordinator = optional(number, 15)
  })
  default = {}
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for workflow stage_bindings.
    Keys: "<workflow-name>::<stage_id>" (stage_id matches the workflow stage).
  EOT
  type        = map(list(string))
  default     = {}
}
