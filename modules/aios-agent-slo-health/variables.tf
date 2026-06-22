variable "model_names" {
  description = <<-EOT
    Ordered list of registered model names for the slo-health agent (highest preference first).
  EOT
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Guardrail policy IDs. `dangerous_ops` is required."
  type = object({
    dangerous_ops = string
  })
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

variable "agent_budget" {
  description = "Daily USD budget for the slo-health agent."
  type        = number
  default     = 12
}

# =============================================================================
# OpenSLO GitHub repository
# =============================================================================

variable "openslo_repository_full_name" {
  description = "GitHub repository (org/name) holding OpenSLO YAML definitions."
  type        = string
}

variable "openslo_path_prefix" {
  description = "Path prefix inside the repo where OpenSLO files live (recursive scan)."
  type        = string
  default     = "openslo/"
}

variable "openslo_branch" {
  description = "Git branch to read OpenSLO specs from."
  type        = string
  default     = "main"
}

variable "openslo_pr_base_branch" {
  description = "Base branch for bootstrap and drift-reconcile pull requests."
  type        = string
  default     = "main"
}

# =============================================================================
# GitHub integration
# =============================================================================

variable "github_secret_id" {
  description = "Optional sg_secret ID for GitHub PAT. Provisions internal integration when set and existing_github_integration_name is empty."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional existing GitHub Guild integration name."
  type        = string
  default     = ""
}

# =============================================================================
# Grafana integration
# =============================================================================

variable "grafana_secret_id" {
  description = "Optional sg_secret ID for Grafana credentials. Provisions internal integration when set and existing_grafana_integration_name is empty."
  type        = string
  default     = ""
}

variable "existing_grafana_integration_name" {
  description = "Optional existing Grafana Guild integration name."
  type        = string
  default     = ""
}

# =============================================================================
# Slack integration (optional)
# =============================================================================

variable "slack_secret_id" {
  description = "Optional sg_secret ID for Slack. Leave empty to skip Slack."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional existing Slack Guild integration name."
  type        = string
  default     = ""
}

variable "slack_channel_hint" {
  description = "Plain-language Slack channel hint for digest and PR notification stages."
  type        = string
  default     = ""
}

# =============================================================================
# Review workflow — error budget + drift
# =============================================================================

variable "slo_report_webhook_url" {
  description = "Optional outbound webhook URL for JSON slo_posture / slo_drift_report POST (notify-webhook stage)."
  type        = string
  default     = ""
}

variable "enable_weekly_schedule" {
  description = "When true, provisions aios-agent-schedules targeting slo-health-review."
  type        = bool
  default     = true
}

variable "weekly_schedule_cron" {
  description = "Five-field cron (UTC) for weekly slo-health-review."
  type        = string
  default     = "0 10 * * 1"
}

variable "burn_rate_windows" {
  description = "Rolling windows for burn-rate interpretation in assess-error-budget runbook."
  type        = list(string)
  default     = ["1h", "6h", "30d"]
}

variable "slo_posture_at_risk_threshold_pct" {
  description = "Remaining error budget percent below which posture is classified at_risk."
  type        = number
  default     = 20
}

variable "enable_slo_drift_in_review" {
  description = "When true, slo-health-review includes scan-grafana-config and detect-config-drift stages."
  type        = bool
  default     = true
}

# =============================================================================
# Bootstrap workflow
# =============================================================================

variable "enable_slo_bootstrap_workflow" {
  description = "When true, creates slo-definition-bootstrap workflow and runbooks."
  type        = bool
  default     = true
}

variable "enable_slo_bootstrap_webhook" {
  description = "When true, creates sg_webhook ingress for slo-definition-bootstrap."
  type        = bool
  default     = false
}

variable "discovery_dashboard_tags" {
  description = "Optional dashboard tag filters for Grafana discovery scans."
  type        = list(string)
  default     = []
}

variable "discovery_dashboard_uids" {
  description = "Optional explicit Grafana dashboard UID allowlist for discovery."
  type        = list(string)
  default     = []
}

variable "discovery_service_label_keys" {
  description = "Prometheus label keys used to group services during discovery and drift linking."
  type        = list(string)
  default     = ["service", "job", "app"]
}

variable "max_slo_proposals_per_run" {
  description = "Maximum new SLO proposals per bootstrap workflow run."
  type        = number
  default     = 10

  validation {
    condition     = var.max_slo_proposals_per_run >= 1 && var.max_slo_proposals_per_run <= 50
    error_message = "max_slo_proposals_per_run must be between 1 and 50."
  }
}

variable "default_availability_target" {
  description = "Default OpenSLO availability objective when inferring from Grafana signals."
  type        = number
  default     = 0.999
}

variable "default_latency_threshold_ms" {
  description = "Default latency threshold (ms) for inferred latency SLOs."
  type        = number
  default     = 500
}

variable "enable_parallel_validate_batches" {
  description = "When true, validate-promql fans out bounded parallel sub-agents (spawn contracts) instead of sequential inline validation."
  type        = bool
  default     = true
}

variable "enable_parallel_draft_batches" {
  description = "When true, draft-openslo-yaml fans out bounded parallel draft-yaml-batch sub-agents after writing validated JSON."
  type        = bool
  default     = true
}

variable "max_parallel_batches" {
  description = "Maximum parallel validate or draft batch sub-agents (2–4). Coordinator assigns proposal IDs round-robin."
  type        = number
  default     = 4

  validation {
    condition     = var.max_parallel_batches >= 2 && var.max_parallel_batches <= 4
    error_message = "max_parallel_batches must be between 2 and 4."
  }
}

# =============================================================================
# Drift reconcile workflow
# =============================================================================

variable "enable_slo_drift_reconcile_workflow" {
  description = "When true, creates slo-drift-reconcile workflow for deep drift analysis and optional PR."
  type        = bool
  default     = true
}

variable "enable_slo_drift_reconcile_webhook" {
  description = "When true, creates sg_webhook ingress for slo-drift-reconcile."
  type        = bool
  default     = false
}

variable "drift_link_by_labels" {
  description = "Label keys used to correlate OpenSLO metadata with Grafana alert/dashboard selectors."
  type        = list(string)
  default     = ["service", "job", "app", "sloth_service"]
}

variable "drift_promql_equivalence_threshold" {
  description = "Documented heuristic: LLM flags structural PromQL diffs; semantic equivalence judged in runbook."
  type        = string
  default     = "semantic"
}

# =============================================================================
# Ubuntu CLI / remote runner (PR paths)
# =============================================================================

variable "enable_ubuntu_cli" {
  description = "When true (and existing_ubuntu_integration_name empty), provisions Ubuntu CLI integration for PR runners."
  type        = bool
  default     = true
}

variable "existing_ubuntu_integration_name" {
  description = "Optional existing Ubuntu CLI Guild integration for git/gh PR operations."
  type        = string
  default     = ""
}

variable "create_remote_runner" {
  description = "When true, registers sg_remote_runner via aios-remote-runner."
  type        = bool
  default     = false
}

variable "remote_runner_name" {
  description = "Remote runner name when create_remote_runner is true."
  type        = string
  default     = ""
}

variable "remote_runner_attach_to_agent" {
  description = "When true, attaches remote runner to slo-health agent for spawn contracts."
  type        = bool
  default     = true
}

variable "remote_runner_description" {
  description = "Optional description for sg_remote_runner."
  type        = string
  default     = ""
}

variable "remote_runner_labels" {
  description = "Optional labels for sg_remote_runner."
  type        = map(string)
  default     = {}
}

# =============================================================================
# Optional webhook ingress URL outputs
# =============================================================================

variable "webhook_trigger_base_url" {
  description = "Optional StackGen HTTP API origin for webhook_trigger_endpoint outputs."
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = "Optional orgId query parameter for webhook_ingress_payload_url outputs."
  type        = string
  default     = ""
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings.
    Keys: "<workflow_name>::<stage_id>".
  EOT
  type        = map(list(string))
  default     = {}
}
