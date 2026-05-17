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
    dangerous_ops          = string
    infra_mutations        = optional(string, "")
    k8s_production         = optional(string, "")
    github_protected       = optional(string, "")
    datadog_alert_triage   = optional(string, "")
    github_org_restriction = optional(string, "")
  })
}

variable "policy_attach_flags" {
  description = <<-EOT
    Plan-time booleans for optional sg_agent_policy_attachment resources whose policy_ids may be
    (known after apply). Defaults are false so omitted optional policies do not create attachments.
    Set a key to true when you supply the corresponding policy_ids value (for example from module.policies).
  EOT
  type = object({
    infra_mutations        = optional(bool, false)
    k8s_production         = optional(bool, false)
    github_protected       = optional(bool, false)
    datadog_alert_triage   = optional(bool, false)
    github_org_restriction = optional(bool, false)
  })
  default = {}
}

variable "secret_names" {
  description = "Secret names from the root module"
  type = object({
    gemini_vault = optional(string, "")
  })
  default = { gemini_vault = "" }
}

# =============================================================================
# Self-contained integration wiring.
# =============================================================================

variable "github_secret_id" {
  description = "Optional `sg_secret` ID for the GitHub PAT. When set, the module provisions an internal GitHub Guild integration for the SCM and PR-reminder agents."
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional `sg_secret` ID for Slack credentials. When set, the module provisions an internal Slack Guild integration for the cloud-infra agent."
  type        = string
  default     = ""
}

variable "aws_secret_id" {
  description = "Optional `sg_secret` ID for AWS credentials. When set, the module provisions an internal AWS Guild integration for the cloud-infra agent."
  type        = string
  default     = ""
}

variable "gcp_secret_id" {
  description = "Optional `sg_secret` ID for GCP credentials. When set, the module provisions an internal GCP Guild integration."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration. Takes precedence over `github_secret_id`."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional Guild integration name to share an existing Slack integration."
  type        = string
  default     = ""
}

variable "existing_aws_integration_name" {
  description = "Optional Guild integration name to share an existing AWS integration."
  type        = string
  default     = ""
}

variable "existing_gcp_integration_name" {
  description = "Optional Guild integration name to share an existing GCP integration."
  type        = string
  default     = ""
}

variable "stackgen_mcp_integration_name" {
  description = "Guild integration name for the StackGen Consumer MCP (tenant-level singleton; not wrapped by an aios-integration-* module)."
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

variable "sre_agent_names" {
  description = "Agent names from the SRE module needed for cross-domain execution plans"
  type = object({
    sre_risk_posture = string
  })
}

variable "sre_runbook_names" {
  description = "Runbook names from the SRE module needed for cross-domain execution plans"
  type = object({
    deployment_rollback = string
    ssl_cert_renewal    = optional(string, "")
  })
}

variable "sre_evidence_checklist_names" {
  description = <<-EOT
    Evidence checklist names managed outside this module (typically from `module.<sre>.workflow_names` or the `sg_evidence_checklist.name` values in `aios-agent-sre`).
    When `change_validation` is non-empty, `sg_workflow.release_pipeline` sets `evidence_checklist_ref` to that name so release proof-of-work aligns with the SRE module.
    Leave empty (default) to omit a workflow-level checklist on the release pipeline; `developer-request-intake` always uses the checklist defined in this module.
  EOT
  type = object({
    change_validation = optional(string, "")
  })
  default = { change_validation = "" }
}

variable "linear_mcp_integration_name" {
  description = "Name of the Linear MCP integration resource (empty if not enabled)"
  type        = string
  default     = ""
}

variable "release_notification_webhook_url" {
  description = <<-EOT
    Optional HTTP(S) URL for deterministic release-status notifications.
    When non-empty, the release-pipeline workflow includes `notify-release-status`
    after the canary gate (and `canary-gate` may PROCEED to that stage). When empty,
    that webhook stage is omitted and `canary-gate` only rolls back to `deploy-staging`
    or finishes without a notification hop.
    The stage POSTs the final deployment outcome (success / rollback) as JSON —
    zero LLM cost, sub-second latency. Typical targets: Slack channel webhook,
    deployment dashboard, or ServiceNow CMDB API.
  EOT
  type        = string
  default     = ""
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow_name>::<stage_id>" where workflow_name is the sg_workflow.name in this module and stage_id matches the stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}

