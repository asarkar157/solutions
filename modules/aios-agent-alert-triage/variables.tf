variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Policy IDs for guardrails"
  type = object({
    dangerous_ops = string
    data_risk_pii = optional(string, "")
  })
}

variable "policy_create_flags" {
  description = "Plan-time flags aligned with module.policies.policy_create_flags for optional attachments."
  type = object({
    data_risk_pii = optional(bool, false)
  })
  default = {}
}

# =============================================================================
# Self-contained integration wiring.
# =============================================================================

variable "grafana_secret_id" {
  description = "Optional `sg_secret` ID for Grafana credentials. When set, the module provisions an internal Grafana Guild integration so agents can ingest alert details."
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional `sg_secret` ID for Slack credentials. When set, the module provisions an internal Slack Guild integration so agents can publish triage results."
  type        = string
  default     = ""
}

variable "existing_grafana_integration_name" {
  description = "Optional Guild integration name to share an existing Grafana integration."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional Guild integration name to share an existing Slack integration."
  type        = string
  default     = ""
}

variable "aws_secret_id" {
  description = "Optional `sg_secret` ID for AWS credentials. When set (and `existing_aws_integration_name` is empty), provisions an internal AWS integration."
  type        = string
  default     = ""
}

variable "existing_aws_integration_name" {
  description = "Optional Guild integration name to share an existing AWS integration."
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

variable "github_default_org" {
  description = "Default GitHub org hint for commit correlation runbooks."
  type        = string
  default     = ""
}

variable "github_default_repos" {
  description = "Default GitHub repo slugs (org/repo) for deploy/commit correlation."
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "AWS region hint for CloudTrail and ECS queries."
  type        = string
  default     = "us-east-1"
}

variable "aws_ecs_cluster_hints" {
  description = "ECS cluster name hints for deploy history correlation."
  type        = list(string)
  default     = []
}

variable "remote_runner_name" {
  description = "Guild remote runner name for K8s enrichment behind the customer firewall."
  type        = string
  default     = ""
}

variable "create_remote_runner" {
  description = "When true (requires non-empty `remote_runner_name`), registers sg_remote_runner via aios-remote-runner."
  type        = bool
  default     = false
}

variable "remote_runner_description" {
  description = "Description for the runner when create_remote_runner is true."
  type        = string
  default     = ""
}

variable "remote_runner_labels" {
  description = "Optional labels on the runner when create_remote_runner is true."
  type        = map(string)
  default     = {}
}

variable "remote_runner_attach_to_agent" {
  description = "When true, attaches the remote runner to rca-investigator for K8s enrichment."
  type        = bool
  default     = true
}

# =============================================================================
# Grafana alert ingest filtering
# =============================================================================

variable "alert_ingest_allowed_severities" {
  description = "When non-empty, Rego ingest filter allows only these severity tokens in the webhook payload."
  type        = list(string)
  default     = []
}

variable "alert_ingest_allowed_environments" {
  description = "When non-empty, Rego ingest filter allows only these environment label values."
  type        = list(string)
  default     = []
}

variable "alert_ingest_allowed_namespaces" {
  description = "When non-empty, Rego ingest filter allows only these namespace label values."
  type        = list(string)
  default     = []
}

variable "alert_ingest_blocked_alert_names" {
  description = "Alert name substrings blocked at ingest (Rego filter)."
  type        = list(string)
  default     = []
}

# =============================================================================
# Knowledge base (optional static postmortems)
# =============================================================================

variable "enable_knowledge_base" {
  description = "When true, creates sg_knowledge_base for optional static RCA/postmortem documents."
  type        = bool
  default     = false
}

variable "knowledge_base_name" {
  description = "Display name for the optional Grafana alert RCA knowledge base."
  type        = string
  default     = "Grafana Alert RCA"
}

# =============================================================================
# Agent budgets
# =============================================================================

variable "agent_budgets" {
  description = "Daily USD budgets per agent."
  type = object({
    alert_ingest = optional(number, 10)
    investigator = optional(number, 25)
    coordinator  = optional(number, 15)
  })
  default = {}
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

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow_name>::<stage_id>" where workflow_name is the sg_workflow.name in this module and stage_id matches the stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}

# ---------------------------------------------------------------------------
# Optional webhook ingress URLs (`POST /api/v1/webhooks/trigger`)
# ---------------------------------------------------------------------------
variable "webhook_trigger_base_url" {
  description = <<-EOT
    Optional StackGen HTTP API origin (e.g. `https://main.dev.stackgen.com`). When set,
    outputs include `webhook_trigger_endpoint` and, when the ingress webhook token exists,
    `webhook_ingress_payload_url` — a full URL with `apiKey=` for Grafana contact points
    and other senders that cannot set `Authorization: Bearer`. Leave empty (default) to
    omit those computed outputs.
  EOT
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = <<-EOT
    Optional `orgId` query parameter appended to `webhook_ingress_payload_url` when
    `webhook_trigger_base_url` is set. Use the same StackGen organization / project id
    you pass as the provider `project_id` for this Guild tenant.
  EOT
  type        = string
  default     = ""
}
