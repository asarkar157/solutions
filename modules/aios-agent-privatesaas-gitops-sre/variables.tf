variable "model_names" {
  description = "Ordered list of registered model names (highest preference first)."
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
  description = "Plan-time flags aligned with module.policies.policy_create_flags."
  type = object({
    sre_remediation = optional(bool, true)
    prod_write_gate = optional(bool, true)
  })
  default = {}
}

# =============================================================================
# GitLab
# =============================================================================

variable "gitlab_base_url" {
  description = "GitLab instance URL when provisioning an internal GitLab integration."
  type        = string
  default     = ""
}

variable "gitlab_private_token" {
  description = "GitLab private access token when provisioning an internal integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "gitlab_secret_id" {
  description = "Optional existing `sg_secret` ID for GitLab credentials."
  type        = string
  default     = ""
}

variable "existing_gitlab_integration_name" {
  description = "Optional Guild integration name to share an existing GitLab integration."
  type        = string
  default     = ""
}

variable "gitlab_default_project_paths" {
  description = "Default GitLab project paths (group/project) for pipeline and MR correlation hints."
  type        = list(string)
  default     = []
}

# =============================================================================
# Argo CD
# =============================================================================

variable "argocd_server_url" {
  description = "Argo CD server URL when provisioning an internal Argo CD integration."
  type        = string
  default     = ""
}

variable "argocd_auth_token" {
  description = "Argo CD API token when provisioning an internal integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "argocd_username" {
  type    = string
  default = ""
}

variable "argocd_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "argocd_secret_id" {
  type    = string
  default = ""
}

variable "existing_argocd_integration_name" {
  type    = string
  default = ""
}

variable "argocd_integration_type" {
  description = "Guild integration type passed to aios-integration-argocd (default argocd)."
  type        = string
  default     = "argocd"
}

variable "argocd_application_hints" {
  description = "Map of logical service names to Argo CD Application names for investigation hints."
  type        = map(string)
  default     = {}
}

# =============================================================================
# SonarQube
# =============================================================================

variable "sonarqube_server_url" {
  type    = string
  default = ""
}

variable "sonarqube_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "sonarqube_secret_id" {
  type    = string
  default = ""
}

variable "existing_sonarqube_integration_name" {
  type    = string
  default = ""
}

variable "sonarqube_project_keys" {
  description = "SonarQube project keys to scope quality-gate lookups."
  type        = list(string)
  default     = []
}

# =============================================================================
# AWS (DynamoDB)
# =============================================================================

variable "aws_secret_id" {
  description = "Required `sg_secret` ID for AWS credentials when provisioning or binding DynamoDB investigation."
  type        = string
  default     = ""
}

variable "existing_aws_integration_name" {
  type    = string
  default = ""
}

variable "dynamodb_table_hints" {
  description = "DynamoDB table name hints for throttle and capacity investigation."
  type        = list(string)
  default     = []
}

# =============================================================================
# Slack (required intake)
# =============================================================================

variable "slack_bot_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "slack_signing_secret" {
  type      = string
  sensitive = true
  default   = ""
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
  default   = ""
}

variable "slack_secret_id" {
  type    = string
  default = ""
}

variable "existing_slack_integration_name" {
  type    = string
  default = ""
}

variable "slack_channel_allowlist" {
  description = "Slack channel names or IDs allowed through slack-ingest-filter (case-insensitive). Empty skips channel gate."
  type        = list(string)
  default     = []
}

variable "slack_ingest_blocked_substrings" {
  description = "Substrings that reject Slack payloads at ingest (case-insensitive)."
  type        = list(string)
  default     = ["password", "api_key", "secret="]
}

variable "slack_ingest_allowed_environment_tags" {
  description = "Environment tags required in Slack text when non-empty (e.g. prod, staging)."
  type        = list(string)
  default     = []
}

variable "slack_notify_channel_hint" {
  description = "Default Slack channel hint for remediation summaries."
  type        = string
  default     = "#sre-gitops"
}

# =============================================================================
# Ubuntu CLI (docker / npm)
# =============================================================================

variable "enable_ubuntu_cli" {
  description = "When true, provisions or uses an Ubuntu MCP integration for docker/npm shell diagnostics (PrivateSaaS sidecar)."
  type        = bool
  default     = false
}

variable "existing_ubuntu_integration_name" {
  type    = string
  default = ""
}

variable "ubuntu_secret_ref_ids" {
  description = "Optional extra sg_secret IDs bound to the Ubuntu integration (e.g. registry tokens)."
  type        = list(string)
  default     = []
}

# =============================================================================
# Remote runner (PoC / on-prem)
# =============================================================================

variable "create_remote_runner" {
  description = "When true (requires non-empty `remote_runner_name`), registers sg_remote_runner via aios-remote-runner."
  type        = bool
  default     = false
}

variable "remote_runner_name" {
  type    = string
  default = ""
}

variable "remote_runner_description" {
  type    = string
  default = ""
}

variable "remote_runner_labels" {
  type    = map(string)
  default = {}
}

variable "remote_runner_attach_to_agent" {
  description = "Attach remote runner to gitops-sre-investigator and gitops-sre-remediator when runner is created."
  type        = bool
  default     = true
}

# =============================================================================
# PrivateSaaS context
# =============================================================================

variable "private_saas_environment_label" {
  type    = string
  default = "privatesaas-gitops"
}

# =============================================================================
# Webhook
# =============================================================================

variable "enable_slack_webhook" {
  description = "When true, creates sg_webhook slack-gitops-sre targeting gitops-sre-incident-response."
  type        = bool
  default     = true
}

variable "webhook_allowed_cidrs" {
  type    = list(string)
  default = []
}

variable "webhook_trigger_base_url" {
  type    = string
  default = ""
}

variable "webhook_trigger_org_id" {
  type    = string
  default = ""
}

# =============================================================================
# Evidence
# =============================================================================

variable "enable_evidence_checklist" {
  description = "When true, creates sg_evidence_checklist gitops-sre-rca on the incident workflow."
  type        = bool
  default     = false
}

# =============================================================================
# Misc
# =============================================================================

variable "name_suffix" {
  type    = string
  default = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "agent_budgets" {
  type = object({
    intake       = optional(number, 10)
    investigator = optional(number, 30)
    remediator   = optional(number, 25)
  })
  default = {}
}

variable "workflow_skill_refs" {
  description = "Optional skill_refs per stage: \"<workflow-logical-name>::<stage_id>\"."
  type        = map(list(string))
  default     = {}
}
