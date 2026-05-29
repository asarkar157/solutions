# =============================================================================
# Scenario: incident-triage
# =============================================================================
# Pre-sales pitch: "We get 200 Grafana alerts a day."
# Grafana ingress -> dynamically routed RCA -> Slack notification.
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

# Bring up the full SRE agent set so alert-triage has a target pool to route to.
module "sre_agents" {
  source = "../../../modules/aios-agent-sre"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops            = module.policies.policy_ids.dangerous_ops
    sre_remediation          = module.policies.policy_ids.sre_remediation
    prod_write_gate          = module.policies.policy_ids.prod_write_gate
    tier0_service_protection = module.policies.policy_ids.tier0_service_protection
    blast_radius_limit       = module.policies.policy_ids.blast_radius_limit
    freeze_window            = module.policies.policy_ids.freeze_window
    data_risk_pii            = module.policies.policy_ids.data_risk_pii
    post_action_verification = module.policies.policy_ids.post_action_verification
  }

  existing_slack_integration_name = module.slack_integration.integration_name
}

module "alert_triage" {
  source = "../../../modules/aios-agent-alert-triage"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_grafana_integration_name = module.grafana_integration.integration_name
  existing_slack_integration_name   = module.slack_integration.integration_name
}
