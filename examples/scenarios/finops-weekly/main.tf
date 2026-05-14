# =============================================================================
# Scenario: finops-weekly
# =============================================================================
# Pre-sales pitch: "We are drowning in cloud spend."
# Cost optimizer + resource janitor + a weekly cron that posts the executive
# summary to Slack. Designed to apply in ~5 minutes.
# See ./README.md for the talk track.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.18, < 0.2.0"
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
}

module "aws_integration" {
  source = "../../../modules/aios-integration-aws"

  aws_role_arn = var.aws_role_arn
  aws_region   = var.aws_region
}

module "slack_integration" {
  source = "../../../modules/aios-integration-slack"

  slack_bot_token = var.slack_bot_token
}

module "cost_optimizer" {
  source = "../../../modules/aios-agent-cost-optimizer"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_aws_integration_name   = module.aws_integration.integration_name
  existing_slack_integration_name = module.slack_integration.integration_name
}

module "resource_janitor" {
  source = "../../../modules/aios-agent-resource-janitor"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_aws_integration_name   = module.aws_integration.integration_name
  existing_slack_integration_name = module.slack_integration.integration_name

  inactivity_days    = var.inactivity_days
  cleanup_dwell_days = 7
}

module "weekly_finops_schedule" {
  source = "../../../modules/aios-agent-schedules"

  target_type = "workflow"
  target_name = module.cost_optimizer.workflow_name

  schedules = [
    {
      name       = "weekly-finops-review"
      expression = "0 9 * * 1" # Mondays 09:00 UTC
      action     = "Run the full FinOps review across the connected AWS account: idle scan, rightsizing, commitment review, anomaly check, then post the executive summary (with savings totals) to Slack."
    },
  ]
}

module "weekly_unused_sweep_schedule" {
  source = "../../../modules/aios-agent-schedules"

  target_type = "workflow"
  target_name = module.resource_janitor.workflow_names.detection

  schedules = [
    {
      name       = "weekly-unused-resource-sweep"
      expression = "0 8 * * 1" # Mondays 08:00 UTC (runs before the FinOps review)
      action     = "Run the detection workflow across the attached AWS account and post a per-team summary to Slack. Read-only — no quarantine in this run."
    },
  ]
}
