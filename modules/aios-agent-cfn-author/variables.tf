variable "model_names" {
  description = "Bedrock-only model list (single entry). Must match expected_bedrock_model_name — typically module.foundation_bedrock.model_names."
  type        = list(string)

  validation {
    condition = (
      length(compact(var.model_names)) == 1 &&
      compact(var.model_names)[0] == var.expected_bedrock_model_name
    )
    error_message = "model_names must contain exactly one non-empty Bedrock model name equal to expected_bedrock_model_name (Bedrock Sonnet 4.6 only)."
  }
}

variable "expected_bedrock_model_name" {
  description = "Guild registered model name for Bedrock Claude Sonnet 4.6 (default claude-sonnet-bedrock from aios-foundation-bedrock)."
  type        = string
  default     = "claude-sonnet-bedrock"
}

variable "policy_ids" {
  description = "Policy IDs from module.policies for agent guardrails."
  type = object({
    dangerous_ops   = string
    prod_write_gate = optional(string, "")
  })
}

variable "policy_create_flags" {
  description = "Plan-time flags aligned with module.policies.policy_create_flags."
  type = object({
    prod_write_gate = optional(bool, true)
  })
  default = {}
}

variable "name_suffix" {
  description = "Optional suffix appended to agent, workflow, and integration resource names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "github_secret_id" {
  description = "Optional sg_secret ID for GitHub PAT. When set and existing_github_integration_name is empty, provisions internal GitHub integration."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional existing GitHub Guild integration name."
  type        = string
  default     = ""
}

variable "aws_secret_id" {
  description = "Optional sg_secret ID for AWS credentials. When existing_aws_integration_name is empty, pass this or aws_role_arn to provision internal AWS integration."
  type        = string
  default     = ""
}

variable "aws_role_arn" {
  description = "Optional AWS IAM role ARN for internal AWS integration when existing_aws_integration_name is empty. Mutually exclusive with aws_secret_id."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for internal AWS integration secret metadata when aws_role_arn is set."
  type        = string
  default     = "us-east-1"
}

variable "existing_aws_integration_name" {
  description = "Optional existing AWS Guild integration name."
  type        = string
  default     = ""
}

variable "workspace" {
  description = <<-EOT
    Default workspace binding for intent, drift, and webhook ingress. Empty fields inherit
    target_repository_full_name, target_base_branch, and cfn_template_path_prefix.
  EOT
  type = object({
    workspace_id         = optional(string, "")
    source_type          = optional(string, "git")
    repository_full_name = optional(string, "")
    base_branch          = optional(string, "")
    path_prefix          = optional(string, "")
    s3_bucket            = optional(string, "")
    s3_prefix            = optional(string, "")
    primary_iac          = optional(string, "cloudformation")
    self_healing_allowed = optional(bool, false)
    force_new_workspace  = optional(bool, false)
  })
  default = {}

  validation {
    condition     = contains(["git", "gitlab", "s3"], coalesce(try(var.workspace.source_type, ""), "git"))
    error_message = "workspace.source_type must be git, gitlab, or s3."
  }

  validation {
    condition     = contains(["cloudformation", "terraform"], coalesce(try(var.workspace.primary_iac, ""), "cloudformation"))
    error_message = "workspace.primary_iac must be cloudformation or terraform."
  }
}

variable "target_repository_full_name" {
  description = "Default GitHub repo (org/name) for CloudFormation template PRs and drift reconcile PRs."
  type        = string
}

variable "target_base_branch" {
  description = "Base branch for PRs opened against target_repository_full_name."
  type        = string
  default     = "main"
}

variable "cfn_template_path_prefix" {
  description = "Directory prefix in the target repo where generated or updated CloudFormation templates are written."
  type        = string
  default     = "cloudformation/"
}

variable "cfn_template_catalog_path" {
  description = "Path within target_repository_full_name to the company's existing CloudFormation template catalog (for best-practice reuse during intent-to-infrastructure)."
  type        = string
  default     = "cloudformation/catalog/"
}

variable "default_aws_regions" {
  description = "AWS regions for drift scans and CloudFormation API calls."
  type        = list(string)
  default     = ["us-east-1"]
}

variable "cloudformation_stack_prefix_allowlist" {
  description = "Stack name prefixes included in drift management scope (empty = all stacks in regions)."
  type        = list(string)
  default     = []
}

variable "stack_tags_environment_key" {
  description = "CloudFormation stack tag key used to identify environment (e.g. Environment)."
  type        = string
  default     = "Environment"
}

variable "allow_prod_change_set_preview" {
  description = "When false, change-set-safety-gate blocks create-change-set preview for prod/production environments."
  type        = bool
  default     = false
}

variable "cfn_lint_max_iterations" {
  description = "Max rework loops from validate-rework-loop back to generate-template."
  type        = number
  default     = 2

  validation {
    condition     = var.cfn_lint_max_iterations >= 1 && var.cfn_lint_max_iterations <= 5
    error_message = "cfn_lint_max_iterations must be between 1 and 5."
  }
}

variable "drift_detection_batch_size" {
  description = "Stacks per parallel drift-detect-runner-batch subagent."
  type        = number
  default     = 5

  validation {
    condition     = var.drift_detection_batch_size >= 1 && var.drift_detection_batch_size <= 20
    error_message = "drift_detection_batch_size must be between 1 and 20."
  }
}

variable "drift_detection_max_retries" {
  description = "Max drift-retry-loop iterations for throttled stack detections."
  type        = number
  default     = 2

  validation {
    condition     = var.drift_detection_max_retries >= 1 && var.drift_detection_max_retries <= 5
    error_message = "drift_detection_max_retries must be between 1 and 5."
  }
}

variable "enable_drift_remediation_pr" {
  description = "When true, open a reconcile PR for drift classified as valid desired state (incorporate via template)."
  type        = bool
  default     = true
}

variable "enable_drift_schedule" {
  description = "When true, provisions aios-agent-schedules targeting cloudformation-drift-management for periodic drift checks."
  type        = bool
  default     = false
}

variable "drift_schedule_cron" {
  description = "Five-field cron for periodic drift management (UTC). Used when enable_drift_schedule is true."
  type        = string
  default     = "0 6 * * *"
}

variable "enable_ubuntu_cli" {
  description = "When true (default), provisions Ubuntu CLI integration for cfn-lint, gh, and git."
  type        = bool
  default     = true
}

variable "existing_ubuntu_integration_name" {
  description = "Optional existing Ubuntu CLI integration name."
  type        = string
  default     = ""
}

variable "ubuntu_secret_ref_ids" {
  description = "Optional additional secret ref IDs for Ubuntu integration."
  type        = list(string)
  default     = []
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
  description = "When true, attaches remote runner to cfn-author and cfn-drift-manager agents."
  type        = bool
  default     = true
}

variable "remote_runner_description" {
  description = "Optional remote runner description."
  type        = string
  default     = ""
}

variable "remote_runner_labels" {
  description = "Optional labels for sg_remote_runner."
  type        = map(string)
  default     = {}
}

variable "enable_evidence_checklist" {
  description = "When true, creates evidence checklists for both workflows."
  type        = bool
  default     = true
}

variable "agent_budget_usd_daily" {
  description = "Daily USD budget cap per agent."
  type        = number
  default     = 25
}

variable "workflow_skill_refs" {
  description = "Optional skill_refs appended per stage. Keys: intent-to-infrastructure::<stage_id> or cloudformation-drift-management::<stage_id>."
  type        = map(list(string))
  default     = {}
}

# =============================================================================
# Intent-to-infrastructure webhook ingress
# =============================================================================

variable "enable_intent_webhook" {
  description = "When true, creates sg_webhook cfn-intent-to-infrastructure targeting the intent-to-infrastructure workflow for remote HTTP triggers."
  type        = bool
  default     = true
}

variable "webhook_allowed_cidrs" {
  description = "Optional CIDR allowlist for the intent-to-infrastructure ingress webhook."
  type        = list(string)
  default     = []
}

variable "webhook_trigger_base_url" {
  description = <<-EOT
    Optional StackGen HTTP API origin (e.g. https://main.dev.stackgen.com). When set,
    outputs include webhook_trigger_endpoint and webhook_ingress_payload_url for remote callers.
  EOT
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = "Optional orgId query parameter appended to webhook_ingress_payload_url when webhook_trigger_base_url is set."
  type        = string
  default     = ""
}

# =============================================================================
# Governance pillars (FedRAMP, baseline, knowledge base, deployment process)
# =============================================================================

variable "org_baseline_name" {
  description = "Organisational infrastructure baseline label for contextual compliance runbooks."
  type        = string
  default     = "organizational-baseline"
}

variable "fedramp_profile" {
  description = "FedRAMP profile for compliance checks (e.g. moderate, high)."
  type        = string
  default     = "moderate"
}

variable "knowledge_base_path" {
  description = "Repo path to hardened IaC knowledge-base snippets used during synthesis."
  type        = string
  default     = "cloudformation/knowledge-base/"
}

variable "deployment_process_doc" {
  description = "Plain-language org deployment process (PR review, change windows, pipelines)."
  type        = string
  default     = "All infrastructure changes require GitHub PR review, cfn-lint/validate pass, and optional change-set preview before merge."
}

variable "architecture_lint_high_rps_threshold" {
  description = "RPS at or above this value triggers high-throughput-web architecture lint rules in architecture-lint.sh."
  type        = number
  default     = 100000
}

variable "enable_contextual_compliance_workflow" {
  description = "When true, provisions standalone cfn-contextual-compliance workflow for CI/CD FedRAMP and baseline preflight."
  type        = bool
  default     = true
}

variable "enable_governed_deployment_workflow" {
  description = "When true, provisions standalone cfn-governed-deployment workflow for org PR process on validated templates."
  type        = bool
  default     = true
}

variable "enable_compliance_webhook" {
  description = "When true and enable_contextual_compliance_workflow is true, creates sg_webhook for contextual-compliance HTTP ingress."
  type        = bool
  default     = false
}

variable "enable_drift_webhook" {
  description = "When true, creates sg_webhook cloudformation-drift-management for batch drifted-stacks HTTP ingress."
  type        = bool
  default     = false
}

variable "enable_security_guardrails_gate" {
  description = "When true, runs Checkov + cfn-nag security guardrails via security-guardrails-gate stage before open-pr."
  type        = bool
  default     = true
}

variable "enable_change_set_preview" {
  description = "When true, intent-to-infrastructure may run preview-changes after open-pr when confirm_deploy is true. When false, change-set preview is always skipped."
  type        = bool
  default     = false
}

variable "max_template_lines" {
  description = "Maximum allowed lines in generated/template.yaml before architecture-lint emits monolith-template-size FAIL."
  type        = number
  default     = 500

  validation {
    condition     = var.max_template_lines >= 100 && var.max_template_lines <= 5000
    error_message = "max_template_lines must be between 100 and 5000."
  }
}
