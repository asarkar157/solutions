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

module "github_integration" {
  source = "../../../modules/aios-integration-github"

  github_token = var.github_token
}

module "grafana_integration" {
  source = "../../../modules/aios-integration-grafana"

  grafana_server = var.grafana_server
  grafana_token  = var.grafana_token
}

module "slack_integration" {
  source = "../../../modules/aios-integration-slack"

  slack_bot_token = var.slack_bot_token
}

module "slo_health" {
  source = "../../../modules/aios-agent-slo-health"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  openslo_repository_full_name = var.openslo_repository_full_name

  existing_github_integration_name  = module.github_integration.integration_name
  existing_grafana_integration_name = module.grafana_integration.integration_name
  existing_slack_integration_name   = module.slack_integration.integration_name

  slo_report_webhook_url = var.slo_report_webhook_url
  slack_channel_hint     = var.slack_channel_hint

  discovery_dashboard_tags = var.discovery_dashboard_tags
}
