# =============================================================================
# Complete AIOS Stack — Full Production Example
# =============================================================================
# This example composes all AIOS module layers to reproduce the full
# Guild production stack from terraform/guild/main.tf.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
}

# =============================================================================
# Layer 0 — Foundation
# =============================================================================

module "foundation" {
  source = "../../modules/aios-foundation"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token

  llm_api_keys = {
    openai    = var.openai_api_key
    anthropic = var.anthropic_api_key
    gemini    = var.gemini_api_key
  }
}

module "policies" {
  source = "../../modules/aios-policies"
}

# =============================================================================
# Layer 1 — Integrations
# =============================================================================

module "aws_integration" {
  source = "../../modules/aios-integration-aws"

  aws_role_arn = var.aws_role_arn
  aws_region   = var.aws_region
}

module "github_integration" {
  source = "../../modules/aios-integration-github"

  github_token = var.github_token
}

module "slack_integration" {
  source = "../../modules/aios-integration-slack"

  slack_bot_token      = var.slack_bot_token
  slack_signing_secret = var.slack_signing_secret
  slack_webhook_url    = var.slack_webhook_url
}

# =============================================================================
# Layer 2 — Agents
# =============================================================================

module "sre_agents" {
  source = "../../modules/aios-agent-sre"

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

  integration_names = {
    slack = module.slack_integration.integration_name
  }
}

module "aws_sre" {
  source = "../../modules/aios-agent-aws-sre"

  model_names      = module.foundation.model_names
  policy_ids       = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  integration_name = module.aws_integration.integration_name
}

module "software_engineering" {
  source = "../../modules/aios-agent-software-engineering"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops        = module.policies.policy_ids.dangerous_ops
    container_shell_hitl = module.policies.policy_ids.container_shell_hitl
  }

  integration_names = {
    github = module.github_integration.integration_name
    slack  = module.slack_integration.integration_name
  }
}

module "cost_optimizer" {
  source = "../../modules/aios-agent-cost-optimizer"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    aws   = module.aws_integration.integration_name
    slack = module.slack_integration.integration_name
  }
}

module "compliance_auditor" {
  source = "../../modules/aios-agent-compliance-auditor"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
    data_risk_pii = module.policies.policy_ids.data_risk_pii
  }

  integration_names = {
    aws    = module.aws_integration.integration_name
    github = module.github_integration.integration_name
  }
}

module "marketing" {
  source = "../../modules/aios-agent-marketing"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
}

module "onboarding" {
  source = "../../modules/aios-agent-onboarding"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    slack  = module.slack_integration.integration_name
    github = module.github_integration.integration_name
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "sre_agent_names" {
  value = module.sre_agents.agent_names
}

output "aws_sre_agent_name" {
  value = module.aws_sre.aws_sre_agent_name
}

output "sre_workflow_names" {
  value = module.sre_agents.workflow_names
}

output "marketing_agent_names" {
  description = "Names of marketing agents (multi-persona module)"
  value         = module.marketing.agent_names
}

output "compliance_agent_name" {
  value = module.compliance_auditor.agent_name
}
