# =============================================================================
# Scenario: pipeline-insights
# =============================================================================
# Pre-sales pitch: "Our CI is a mess; what do you actually see?"
# Read-only — no production credentials needed. Lowest-friction first demo.
# See ./README.md for the talk track.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.20, < 0.2.0"
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

module "github_integration" {
  source = "../../../modules/aios-integration-github"

  github_token = var.github_token
}

module "slack_integration" {
  count  = trimspace(var.slack_bot_token) != "" ? 1 : 0
  source = "../../../modules/aios-integration-slack"

  slack_bot_token = var.slack_bot_token
}

module "pipeline_insights" {
  source = "../../../modules/aios-agent-pipeline-insights"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_github_integration_name = module.github_integration.integration_name
  existing_slack_integration_name  = length(module.slack_integration) > 0 ? module.slack_integration[0].integration_name : ""
}

module "release_tracker" {
  source = "../../../modules/aios-agent-release-tracker"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_github_integration_name = module.github_integration.integration_name
  existing_slack_integration_name  = length(module.slack_integration) > 0 ? module.slack_integration[0].integration_name : ""

  service_catalog          = var.service_catalog
  image_namespace_template = var.image_namespace_template
}
