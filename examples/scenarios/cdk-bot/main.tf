# Scenario: cdk-bot — AWS CDK module manager agent

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
  insecure       = var.stackgen_insecure
}

module "foundation" {
  source = "../../../modules/aios-foundation"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id

  llm_api_keys = {
    openai    = var.openai_api_key
    anthropic = var.anthropic_api_key
    gemini    = var.gemini_api_key
  }
}

module "policies" {
  source = "../../../modules/aios-policies"

  create_policies = {
    azure_tool_governance  = false
    google_tool_governance = false
    langfuse_observability = false
  }
}

module "cdk_bot" {
  source = "../../../modules/aios-agent-cdk-bot"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
  }

  github_token = var.github_token

  discovery_modules_repository_full_names = var.cdk_catalog_repository_full_names
  discovery_modules_issue_label           = var.cdk_catalog_issue_label

  enable_aws_validation         = var.enable_aws_validation
  existing_aws_integration_name = var.existing_aws_integration_name
  aws_role_arn                  = var.aws_role_arn
  aws_region                    = var.aws_region

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id
}
