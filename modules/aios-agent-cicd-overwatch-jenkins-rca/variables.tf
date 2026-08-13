variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agent (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Optional policy IDs from module.policies for agent guardrails. Omit or leave empty to skip attachment (e.g. when module.policies hasn't been provisioned yet)."
  type = object({
    dangerous_ops   = optional(string, "")
    prod_write_gate = optional(string, "")
  })
  default = {}
}

variable "policy_create_flags" {
  description = "Plan-time flags aligned with module.policies.policy_create_flags. Drives count on optional sg_agent_policy_attachment resources."
  type = object({
    dangerous_ops   = optional(bool, true)
    prod_write_gate = optional(bool, true)
  })
  default = {}
}

# =============================================================================
# Jenkins integration wiring
# =============================================================================

variable "existing_jenkins_integration_name" {
  description = "Guild integration name to share an existing Jenkins integration (e.g. the `jenkins` integration already registered in your StackGen project)."
  type        = string
  default     = ""
}

variable "jenkins_base_url" {
  description = "Jenkins controller base URL when provisioning an internal Jenkins integration (ignored if existing_jenkins_integration_name is set)."
  type        = string
  default     = ""
}

variable "jenkins_username" {
  description = "Jenkins username when provisioning an internal Jenkins integration."
  type        = string
  default     = ""
}

variable "jenkins_token" {
  description = "Jenkins API token/password when provisioning an internal Jenkins integration."
  type        = string
  sensitive   = true
  default     = ""
}

variable "jenkins_secret_id" {
  description = "Optional existing `sg_secret` ID for Jenkins credentials."
  type        = string
  default     = ""
}

# =============================================================================
# Linear integration wiring
# =============================================================================

variable "existing_linear_integration_name" {
  description = "Guild integration name to share an existing Linear integration (e.g. the `devops-linear` integration already registered in your StackGen project)."
  type        = string
  default     = ""
}

variable "linear_api_key" {
  description = "Linear personal API key when provisioning an internal Linear integration (ignored if existing_linear_integration_name is set)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "linear_credential_provider_id" {
  description = "Optional OAuth credential provider ID for Linear (mutually exclusive with linear_api_key)."
  type        = string
  default     = ""
}

variable "linear_secret_id" {
  description = "Optional existing `sg_secret` ID for Linear credentials."
  type        = string
  default     = ""
}

# =============================================================================
# Optional AWS integration wiring (artifact / deployment evidence)
# =============================================================================

variable "existing_aws_integration_name" {
  description = "Optional Guild integration name to share an existing AWS integration for artifact/deployment evidence. Leave empty to skip AWS-side investigation."
  type        = string
  default     = ""
}

variable "aws_role_arn" {
  description = "AWS IAM role ARN when provisioning an internal AWS integration (ignored if existing_aws_integration_name is set)."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "Default AWS region when provisioning an internal AWS integration."
  type        = string
  default     = "us-east-1"
}

variable "aws_secret_id" {
  description = "Optional existing `sg_secret` ID for AWS credentials."
  type        = string
  default     = ""
}

# =============================================================================
# Optional GitHub integration wiring (source / contract evidence)
# =============================================================================

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration for source/contract evidence. Leave empty to skip source-control investigation."
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub personal access token when provisioning an internal GitHub integration (ignored if existing_github_integration_name is set)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_secret_id" {
  description = "Optional existing `sg_secret` ID for GitHub credentials."
  type        = string
  default     = ""
}

# =============================================================================
# Knowledge base (CICD Overwatch reference documents)
# =============================================================================

variable "enable_knowledge_base" {
  description = "When true, creates sg_knowledge_base and uploads the CICD Overwatch reference documents shipped under `knowledge/` in this module."
  type        = bool
  default     = true
}

variable "knowledge_source_repo" {
  description = "GitHub `owner/repo` this module is published from. Used to build raw.githubusercontent.com source URLs for the bundled knowledge documents."
  type        = string
  default     = "asarkar157/solutions"
}

variable "knowledge_source_ref" {
  description = "Git ref (branch or tag) to fetch bundled knowledge documents from. Must already be pushed before apply."
  type        = string
  default     = "main"
}

# =============================================================================
# Webhook ingress
# =============================================================================

variable "enable_linear_webhook" {
  description = "When true, creates sg_webhook `cicd-overwatch-linear-ticket-receiver` targeting the cicd-overwatch-jenkins-rca workflow for Linear ingress."
  type        = bool
  default     = true
}

variable "webhook_allowed_cidrs" {
  description = "Optional CIDR allowlist for the Linear ingress webhook."
  type        = list(string)
  default     = []
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

variable "agent_budget_usd" {
  description = "Daily budget limit (USD) for the investigator agent."
  type        = number
  default     = 20
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional additional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "cicd-overwatch-jenkins-rca::<stage_id>" where stage_id matches the workflow stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}
