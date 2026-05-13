# =============================================================================
# Scenario: aws-sre-demo
# =============================================================================
# Pre-sales pitch: "Can your thing actually fix an AWS incident?"
# Wires foundation + policies + AWS + (optional) Slack + the AWS-SRE agent.
# Designed to apply in ~5 minutes against a fresh Guild tenant.
# See ./README.md for the talk track.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
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

module "aws_integration" {
  source = "../../../modules/aios-integration-aws"

  aws_role_arn = var.aws_role_arn
  aws_region   = var.aws_region
}

module "slack_integration" {
  count  = trimspace(var.slack_bot_token) != "" ? 1 : 0
  source = "../../../modules/aios-integration-slack"

  slack_bot_token = var.slack_bot_token
}

module "aws_sre" {
  source = "../../../modules/aios-agent-aws-sre"

  model_names      = module.foundation.model_names
  policy_ids       = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  integration_name = module.aws_integration.integration_name
}
