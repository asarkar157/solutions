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
# Self-contained AWS integration wiring
# =============================================================================

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

# =============================================================================
# Self-hosted CloudFormation context
# =============================================================================

variable "self_hosted_environment_label" {
  description = "Human-readable label for the self-hosted environment (e.g. prod-us-east-1-vpc) injected into runbooks and workflow descriptions."
  type        = string
  default     = "selfhosted"
}

variable "cloudformation_stack_prefix_allowlist" {
  description = "Stack name prefixes allowed through the stack-ingest-filter Rego gate (case-insensitive). Empty list skips the prefix gate."
  type        = list(string)
  default     = []
}

variable "blocked_stack_names" {
  description = "CloudFormation stack names rejected at ingest (case-insensitive substring match on payload text)."
  type        = list(string)
  default     = []
}

variable "default_aws_regions" {
  description = "Default AWS regions for stack inventory and investigation when the payload omits a region."
  type        = list(string)
  default     = ["us-east-1"]
}

variable "stack_tags_environment_key" {
  description = "CloudFormation stack tag key used to identify environment (e.g. Environment, env)."
  type        = string
  default     = "Environment"
}

variable "cloudformation_stack_hints" {
  description = "Optional map of stack name hints to investigation context (owning team, expected resources, notes)."
  type        = map(string)
  default     = {}
}

# =============================================================================
# Stack ingest filtering (deterministic policy_check at workflow ingress)
# =============================================================================

variable "stack_ingest_allowed_environment_tags" {
  description = "Environment tag values required when non-empty (e.g. production, staging). Empty list skips the environment gate."
  type        = list(string)
  default     = []
}

# =============================================================================
# Optional Ubuntu CLI + remote runner (self-hosted PoC in customer VPC)
# =============================================================================

variable "enable_ubuntu_cli" {
  description = "When true (or when create_remote_runner is true), provisions an Ubuntu CLI integration for cfn-lint and shell diagnostics."
  type        = bool
  default     = false
}

variable "existing_ubuntu_integration_name" {
  description = "Optional Guild integration name to share an existing Ubuntu CLI integration."
  type        = string
  default     = ""
}

variable "ubuntu_secret_ref_ids" {
  description = "Optional secret ref IDs forwarded to aios-integration-ubuntu when provisioning Ubuntu CLI."
  type        = list(string)
  default     = []
}

variable "create_remote_runner" {
  description = "When true, registers an sg_remote_runner via aios-remote-runner (requires remote_runner_name; provider >= 0.1.25)."
  type        = bool
  default     = false
}

variable "remote_runner_name" {
  description = "Name for the remote runner when create_remote_runner is true."
  type        = string
  default     = ""
}

variable "remote_runner_description" {
  description = "Optional description for the remote runner."
  type        = string
  default     = ""
}

variable "remote_runner_labels" {
  description = "Optional labels for the remote runner."
  type        = map(string)
  default     = {}
}

variable "remote_runner_attach_to_agent" {
  description = "Attach remote runner to infra-investigator and infra-change-engineer when runner is created."
  type        = bool
  default     = true
}

# =============================================================================
# Webhook ingress
# =============================================================================

variable "enable_stack_failure_webhook" {
  description = "When true, creates sg_webhook cloudformation-stack-failure targeting cloudformation-stack-incident."
  type        = bool
  default     = true
}

variable "webhook_allowed_cidrs" {
  description = "Optional CIDR allowlist for the CloudFormation failure ingress webhook."
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

# =============================================================================
# Evidence
# =============================================================================

variable "enable_evidence_checklist" {
  description = "When true, creates sg_evidence_checklist selfhosted-infra-rca on the stack-incident workflow."
  type        = bool
  default     = false
}

# =============================================================================
# Misc
# =============================================================================

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
    event_ingest    = optional(number, 10)
    investigator    = optional(number, 25)
    change_engineer = optional(number, 25)
  })
  default = {}
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow-logical-name>::<stage_id>" where stage_id matches the workflow stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}
