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
    dangerous_ops = string
    data_risk_pii = optional(string, "")
  })
}

variable "policy_create_flags" {
  description = <<-EOT
    Align with module.policies.policy_create_flags for optional attachments. Drives Terraform count
    on the data_risk_pii attachment so count does not depend on unknown policy_ids. Set data_risk_pii
    to true when you pass module.policies.policy_ids.data_risk_pii from the same stack.
  EOT
  type = object({
    data_risk_pii = optional(bool, false)
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

variable "gcp_credentials_json" {
  description = "GCP service account key JSON when provisioning an internal GCP integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "gcp_project_id" {
  description = "GCP project ID hint for Cloud Logging queries and integration provisioning."
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP region hint for logging and monitoring queries."
  type        = string
  default     = "us-central1"
}

variable "gcp_secret_id" {
  description = "Optional existing `sg_secret` ID for GCP credentials. When set (and `existing_gcp_integration_name` is empty), the module provisions an internal GCP Guild integration."
  type        = string
  default     = ""
}

variable "existing_gcp_integration_name" {
  description = "Optional Guild integration name to share an existing GCP integration instead of provisioning one."
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

variable "github_token" {
  description = "GitHub personal access token when provisioning an internal GitHub integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_secret_id" {
  description = "Optional existing `sg_secret` ID for GitHub credentials."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration."
  type        = string
  default     = ""
}

variable "enable_cce" {
  description = "When true and GitHub is wired, provisions Ubuntu + CCE for incident-scoping on default repos."
  type        = bool
  default     = true
}

variable "existing_ubuntu_integration_name" {
  description = "Optional Guild integration name to share an existing Ubuntu CLI integration."
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

# =============================================================================
# Multi-tenant alert ingest filtering
# =============================================================================

variable "tenant_tag_key" {
  description = "Datadog tag key used to extract tenant scope from alert payloads (e.g. tenant_id, customer_id)."
  type        = string
  default     = "tenant_id"
}

variable "alert_ingest_allowed_priorities" {
  description = "Datadog alert priorities allowed through the ingest filter (case-insensitive, e.g. p2, p3, critical). Empty list skips the priority gate."
  type        = list(string)
  default     = ["p2", "p3", "p4", "critical", "high"]
}

variable "alert_ingest_allowed_tenant_ids" {
  description = "Tenant IDs allowed through ingest when non-empty. Empty list skips the tenant allowlist gate."
  type        = list(string)
  default     = []
}

variable "alert_ingest_blocked_services" {
  description = "Service names or tag substrings rejected at ingest (case-insensitive substring match on payload text)."
  type        = list(string)
  default     = []
}

# =============================================================================
# Investigation hints
# =============================================================================

variable "slack_rca_channel" {
  description = "Slack channel name or ID where RCA summaries are posted (e.g. #sre-rca or C01234567)."
  type        = string
  default     = ""
}

variable "slack_collaboration_channel_hint" {
  description = "Optional Slack channel hint for thread collaboration runbook context."
  type        = string
  default     = ""
}

variable "github_default_org" {
  description = "Default GitHub organization for commit and blame lookups during cross-signal investigation."
  type        = string
  default     = ""
}

variable "github_default_repos" {
  description = "Default GitHub repository slugs (org/repo) for commit history and blame on suspect paths."
  type        = list(string)
  default     = []
}

variable "aws_ecs_cluster_hints" {
  description = "Map of service or tenant slug to ECS cluster name hints for deployment history lookups."
  type        = map(string)
  default     = {}
}

# =============================================================================
# Webhook ingress
# =============================================================================

variable "enable_datadog_webhook" {
  description = "When true, creates sg_webhook `datadog-alert-receiver` targeting datadog-multitenant-rca for Datadog monitor alert ingress."
  type        = bool
  default     = true
}

variable "enable_slack_collaboration_webhook" {
  description = "Deprecated. When true, creates legacy sg_webhook slack-rca-thread (source=slack). Prefer Gateway /slack/events → aiden-router for thread follow-up."
  type        = bool
  default     = false
}

variable "webhook_allowed_cidrs" {
  description = "Optional CIDR allowlist for ingress webhooks."
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
  description = "Optional `orgId` query parameter appended to webhook ingress payload URLs when `webhook_trigger_base_url` is set."
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
    investigator = optional(number, 30)
    publisher    = optional(number, 10)
    collaborator = optional(number, 20)
  })
  default = {}
}

variable "enable_evidence_checklist" {
  description = "When true, creates sg_evidence_checklist multitenant-rca and attaches it to the primary RCA workflow."
  type        = bool
  default     = true
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow-logical-name>::<stage_id>" where workflow-logical-name is
    datadog-multitenant-rca or datadog-rca-collaboration and stage_id matches the workflow stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}
