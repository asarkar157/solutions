variable "model_names" {
  description = "Bedrock model names for cfn-author (must be foundation-bedrock output)."
  type        = list(string)
}

variable "policy_ids" {
  description = "Policy id map: dangerous_ops, prod_write_gate required."
  type = object({
    dangerous_ops   = string
    prod_write_gate = optional(string)
  })
}

variable "target_repository_full_name" {
  description = "GitHub org/repo for CloudFormation templates."
  type        = string
}

variable "target_base_branch" {
  type    = string
  default = "main"
}

variable "org_baseline_name" {
  type    = string
  default = "org-prod-baseline"
}

variable "fedramp_profile" {
  type    = string
  default = "moderate"
}

variable "github_secret_id" {
  type    = string
  default = ""
}

variable "aws_secret_id" {
  type    = string
  default = ""
}

variable "aws_role_arn" {
  type    = string
  default = ""
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "existing_github_integration_name" {
  type    = string
  default = ""
}

variable "existing_aws_integration_name" {
  type    = string
  default = ""
}

variable "existing_ubuntu_integration_name" {
  type    = string
  default = ""
}

variable "stackgen_token_secret_id" {
  description = "StackGen token secret for terraform-bot register/upload when enable_terraform_bot is true."
  type        = string
  default     = ""
}

variable "workspace" {
  description = "Workspace binding forwarded to cfn-author."
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
}

variable "enable_intent_webhook" {
  type    = bool
  default = true
}

variable "enable_compliance_webhook" {
  type    = bool
  default = true
}

variable "enable_drift_webhook" {
  type    = bool
  default = false
}

variable "enable_drift_schedule" {
  type    = bool
  default = false
}

variable "enable_security_guardrails_gate" {
  type    = bool
  default = true
}

variable "webhook_trigger_base_url" {
  type    = string
  default = ""
}

variable "webhook_trigger_org_id" {
  type    = string
  default = ""
}

variable "enable_terraform_bot" {
  description = "When true, also provisions aios-agent-terraform-bot for dual IaC (CFN + TF module quality)."
  type        = bool
  default     = false
}

variable "terraform_bot_model_names" {
  description = "Optional separate model list for terraform-bot; defaults to model_names."
  type        = list(string)
  default     = null
}

variable "terraform_bot_github_integration_name" {
  type    = string
  default = ""
}

variable "terraform_bot_ubuntu_integration_name" {
  type    = string
  default = ""
}

variable "terraform_bot_create_remote_runner" {
  type    = bool
  default = false
}

variable "terraform_bot_remote_runner_attach" {
  type    = bool
  default = false
}
