terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

# Thin composition: CloudFormation Author + optional Terraform Module Bot.
# Does not create a second StackGen MCP — attach existing stackgen-mcp by name when needed.

locals {
  terraform_bot_github_integration_name = coalesce(
    trimspace(var.terraform_bot_github_integration_name) != "" ? trimspace(var.terraform_bot_github_integration_name) : null,
    trimspace(var.existing_github_integration_name) != "" ? trimspace(var.existing_github_integration_name) : null,
    module.cfn_author.github_integration_name,
  )
  terraform_bot_ubuntu_integration_name = coalesce(
    trimspace(var.terraform_bot_ubuntu_integration_name) != "" ? trimspace(var.terraform_bot_ubuntu_integration_name) : null,
    trimspace(var.existing_ubuntu_integration_name) != "" ? trimspace(var.existing_ubuntu_integration_name) : null,
    module.cfn_author.ubuntu_integration_name,
  )
}

module "cfn_author" {
  source = "../aios-agent-cfn-author"

  model_names = var.model_names
  policy_ids  = var.policy_ids

  target_repository_full_name = var.target_repository_full_name
  target_base_branch          = var.target_base_branch
  org_baseline_name           = var.org_baseline_name
  fedramp_profile             = var.fedramp_profile

  github_secret_id = var.github_secret_id
  aws_secret_id    = var.aws_secret_id
  aws_role_arn     = var.aws_role_arn
  aws_region       = var.aws_region

  existing_github_integration_name = var.existing_github_integration_name
  existing_aws_integration_name    = var.existing_aws_integration_name
  existing_ubuntu_integration_name = var.existing_ubuntu_integration_name

  workspace = var.workspace

  enable_intent_webhook           = var.enable_intent_webhook
  enable_compliance_webhook       = var.enable_compliance_webhook
  enable_drift_webhook            = var.enable_drift_webhook
  enable_drift_schedule           = var.enable_drift_schedule
  enable_security_guardrails_gate = var.enable_security_guardrails_gate

  webhook_trigger_base_url = var.webhook_trigger_base_url
  webhook_trigger_org_id   = var.webhook_trigger_org_id
}

module "terraform_bot" {
  count  = var.enable_terraform_bot ? 1 : 0
  source = "../aios-agent-terraform-bot"

  model_names = var.terraform_bot_model_names != null ? var.terraform_bot_model_names : var.model_names
  policy_ids  = var.policy_ids

  github_secret_id = var.github_secret_id

  existing_github_integration_name = local.terraform_bot_github_integration_name
  existing_ubuntu_integration_name = local.terraform_bot_ubuntu_integration_name

  stackgen_token_secret_id = var.stackgen_token_secret_id

  create_remote_runner          = var.terraform_bot_create_remote_runner
  remote_runner_attach_to_agent = var.terraform_bot_remote_runner_attach
}
