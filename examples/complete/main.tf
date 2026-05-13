# =============================================================================
# Complete AIOS Stack — Full Production Example
# =============================================================================
# This example composes all AIOS module layers to reproduce the full
# Guild production stack from terraform/guild/main.tf.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # Align with modules that use sg_agent.remote_runners / sg_remote_runner (>= 0.1.12).
      version = ">= 0.1.12, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  # When non-empty, scopes Guild data sources and resources that send orgId (agents, workflows, webhooks, schedules).
  project_id = var.stackgen_project_id != "" ? var.stackgen_project_id : null
  # Default true: some Guild resources may adopt an existing remote object after Create returns 409/500.
  # adopt_on_conflict = false
}

# =============================================================================
# Layer 0 — Foundation
# =============================================================================

module "foundation" {
  source = "../../modules/aios-foundation"

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

module "ubuntu_integration" {
  source = "../../modules/aios-integration-ubuntu"
}

# =============================================================================
# Layer 2 — Agents
# =============================================================================

module "sre_agents" {
  source = "../../modules/aios-agent-sre"

  policy_create_flags = {
    sre_remediation          = module.policies.policy_create_flags.sre_remediation
    prod_write_gate          = module.policies.policy_create_flags.prod_write_gate
    tier0_service_protection = module.policies.policy_create_flags.tier0_service_protection
    blast_radius_limit       = module.policies.policy_create_flags.blast_radius_limit
    freeze_window            = module.policies.policy_create_flags.freeze_window
    data_risk_pii            = module.policies.policy_create_flags.data_risk_pii
    post_action_verification = module.policies.policy_create_flags.post_action_verification
  }

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

# Example: attach Guild cron schedules to any agent via the composable schedules module.
module "aws_sre_schedules" {
  source = "../../modules/aios-agent-schedules"

  target_name = module.aws_sre.aws_sre_agent_name

  schedules = [
    {
      name       = "weekly-aws-tag-audit"
      expression = "0 10 * * 1" # Mondays 10:00 UTC
      action     = "Run a read-only tagging sanity check on EC2 and RDS in the connected account; list resources missing required tags and summarize."
    },
  ]
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

module "terraform_bot" {
  source = "../../modules/aios-agent-terraform-bot"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    github     = module.github_integration.integration_name
    ubuntu_cli = module.ubuntu_integration.integration_name
  }

  # Optional remote runner (provider >= 0.1.12): set name + remote_runner_attach_to_agent = true
  # remote_runner_name              = "my-org-tofu-runner"
  # remote_runner_attach_to_agent   = true
}

module "db_state_splitter" {
  source = "../../modules/aios-agent-db-state-splitter"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  integration_names = {
    github     = module.github_integration.integration_name
    ubuntu_cli = module.ubuntu_integration.integration_name
  }

  # StackGen MCP: set to a real integration name when AppStack materialization is required.
  stackgen_mcp_integration_name = ""

  enable_github_webhook = false

  # When you run the workflow in Guild, ensure monolith_state_uri is reachable from the
  # Ubuntu integration / remote runner (S3/GCS/Azure creds, not just GitHub raw URLs in prod).

  # Optional: Guild remote runner — SOP text only unless attach is true (requires runner to exist at plan time).
  # remote_runner_name              = "my-org-tofu-runner"
  # remote_runner_attach_to_agent   = true
}

# =============================================================================
# Optional: Guild read-only data sources (StackGen provider)
# =============================================================================
# Uncomment after a successful apply if you want Terraform to refresh lists of
# remote agents/workflows (useful for outputs, debugging, or downstream modules).
# Set provider project_id above when the Guild API requires org scope.
#
# data "sg_workflows" "guild" {
#   # limit    = 100
#   # offset   = 0
#   # include_drafts = false
#   # latest_only    = true
# }
#
# data "sg_agents" "guild" {}
#
# output "guild_workflow_names" {
#   value = [for w in data.sg_workflows.guild.workflows : w.name]
# }
#
# output "guild_agent_count" {
#   value = length(data.sg_agents.guild.agents)
# }

# =============================================================================
# Outputs
# =============================================================================

output "sre_agent_names" {
  value = module.sre_agents.agent_names
}

output "aws_sre_agent_name" {
  value = module.aws_sre.aws_sre_agent_name
}

output "aws_sre_schedule_ids" {
  description = "Example sg_agent_schedule ids attached to aws_sre (see module aws_sre_schedules)."
  value       = module.aws_sre_schedules.schedule_ids
}

output "sre_workflow_names" {
  value = module.sre_agents.workflow_names
}

output "marketing_agent_names" {
  description = "Names of marketing agents (multi-persona module)"
  value       = module.marketing.agent_names
}

output "compliance_agent_name" {
  value = module.compliance_auditor.agent_name
}

output "terraform_bot_webhook" {
  description = "Webhook endpoint for Terraform Module Bot ingress from GitHub"
  value = {
    id    = module.terraform_bot.webhook_id
    token = module.terraform_bot.webhook_token
  }
  sensitive = true
}

output "db_state_splitter_workflows" {
  description = "DB monorepo state split + orphan module authoring workflow names"
  value       = module.db_state_splitter.workflow_names
}
