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
      # Align with AIOS modules: 0.1.17 adds integration `env` (consumed by aios-integration-ubuntu and exposed
      # as optional input on other containerized integrations) and adopt-on-conflict for sg_policy_bundle,
      # sg_guild_model_provider, sg_guild_model, and already-approved sg_workflow.
      version = ">= 0.1.18, < 0.2.0"
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

# Optional: only created when grafana_token is set. Required by the
# alert-triage agent below so incoming Grafana alerts can be triaged and
# posted to Slack.
module "grafana_integration" {
  count  = var.grafana_token != "" ? 1 : 0
  source = "../../modules/aios-integration-grafana"

  grafana_server = var.grafana_server
  grafana_token  = var.grafana_token
}

# -----------------------------------------------------------------------------
# StackGen Consumer MCP (required by aios-agent-db-state-splitter)
# -----------------------------------------------------------------------------
# Hosted MCP URL per StackGen docs: /api/mcp/user (Consumer).
# Vault Other/mcp: transport, url, headers — MCPSecretResolver.

locals {
  stackgen_mcp_url = format("%s/api/mcp/user", trimsuffix(var.stackgen_url, "/"))
  stackgen_mcp_auth_header = jsonencode({
    authorization = "Bearer ${var.stackgen_token}"
  })
}

resource "sg_secret" "stackgen_mcp" {
  name        = "stackgen-mcp-credentials"
  description = "StackGen Consumer MCP — transport streamable_http; PAT in Authorization header; url /api/mcp/user."
  category    = "Other"
  subcategory = "mcp"

  metadata = {
    transport = "streamable_http"
    url       = local.stackgen_mcp_url
    headers   = local.stackgen_mcp_auth_header
  }
}

resource "sg_guild_integration" "stackgen_mcp" {
  name        = "stackgen-mcp"
  description = "StackGen hosted MCP — Consumer endpoint for platform tools."
  type        = "mcp"
  scope       = "PROJECT"
  enabled     = true

  secret_ref_ids = [sg_secret.stackgen_mcp.id]
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

  # Self-contained pattern: share the tenant-level Slack integration. Pass
  # `slack_secret_id = module.slack_integration.secret_id` instead to let
  # this module provision its OWN slack-prefixed integration.
  existing_slack_integration_name = module.slack_integration.integration_name
}

module "aws_sre" {
  source = "../../modules/aios-agent-aws-sre"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  # Share the tenant-level AWS integration. To provision a dedicated
  # `aws-sre-aws` instance instead, pass `aws_secret_id = module.aws_integration.secret_id`.
  existing_aws_integration_name = module.aws_integration.integration_name
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

  # Share tenant-level GitHub + Slack. Drop the existing_* lines (or replace
  # with `*_secret_id = module.*.secret_id`) to provision module-owned copies.
  existing_github_integration_name = module.github_integration.integration_name
  existing_slack_integration_name  = module.slack_integration.integration_name

  # Required passthrough — no aios-integration-linear-mcp / -cursor-mcp wrappers
  # exist yet. Set these to pre-provisioned Guild integration names.
  existing_linear_mcp_integration_name = var.linear_mcp_integration_name
  existing_cursor_mcp_integration_name = var.cursor_mcp_integration_name
}

module "cost_optimizer" {
  source = "../../modules/aios-agent-cost-optimizer"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_aws_integration_name   = module.aws_integration.integration_name
  existing_slack_integration_name = module.slack_integration.integration_name
}

# Weekly FinOps report — Mondays 09:00 UTC. Drives the cost-optimizer's
# finops-review workflow to summarize spend, idle resources, rightsizing,
# and anomalies, then post the executive summary to Slack.
module "cost_optimizer_weekly" {
  source = "../../modules/aios-agent-schedules"

  target_type = "workflow"
  target_name = module.cost_optimizer.workflow_name

  schedules = [
    {
      name       = "weekly-finops-review"
      expression = "0 9 * * 1"
      action     = "Run the full FinOps review across the connected AWS account: idle scan, rightsizing, commitment review, anomaly check, then post the executive summary (with savings totals) to the configured Slack channel."
    },
  ]
}

# Use case: Automated alert RCA + dedicated Slack notifications.
# Receives Grafana alert webhooks, dynamically routes triage to the best-fit
# cloud agent (AWS / Azure / K8s / Remote Runner), then posts the findings
# to Slack. Only wired when grafana_token is set so the Grafana integration
# above exists at apply time.
module "alert_triage" {
  count  = var.grafana_token != "" ? 1 : 0
  source = "../../modules/aios-agent-alert-triage"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_grafana_integration_name = module.grafana_integration[0].integration_name
  existing_slack_integration_name   = module.slack_integration.integration_name
}

# Use case: Unused resource detection (≥ 30 days inactive) + cleanup automation.
# Detection is read-only; cleanup is HITL-gated through the dangerous-ops policy
# with a tag-and-quarantine dwell window.
module "resource_janitor" {
  source = "../../modules/aios-agent-resource-janitor"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_aws_integration_name   = module.aws_integration.integration_name
  existing_slack_integration_name = module.slack_integration.integration_name

  inactivity_days       = 30
  cleanup_dwell_days    = 7
  max_resources_per_run = 25
  cleanup_dollar_cap    = 1000
}

# Periodic detection — runs every Monday at 08:00 UTC, before the FinOps
# review at 09:00 UTC, so the executive summary can reference fresh
# unused-resource findings.
module "resource_janitor_schedules" {
  source = "../../modules/aios-agent-schedules"

  target_type = "workflow"
  target_name = module.resource_janitor.workflow_names.detection

  schedules = [
    {
      name       = "weekly-unused-resource-sweep"
      expression = "0 8 * * 1"
      action     = "Run the detection workflow across all attached cloud integrations and post a per-team summary to Slack. Read-only — no quarantine in this run."
    },
  ]
}

# Use case: GitHub pipeline insights & deployment intelligence.
# Conversational, read-only. Use Guild chat or wire a Slack mention bridge
# to the optional `slack-pipeline-insights` webhook (set enable_slack_webhook).
module "pipeline_insights" {
  source = "../../modules/aios-agent-pipeline-insights"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_github_integration_name = module.github_integration.integration_name
  existing_slack_integration_name  = module.slack_integration.integration_name

  enable_slack_webhook = false
}

# Use case: Microservice tag discovery & release tracking.
# Conversational, read-only. Optional service catalog so operators can ask
# by service_name instead of repository.
module "release_tracker" {
  source = "../../modules/aios-agent-release-tracker"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  existing_github_integration_name = module.github_integration.integration_name
  existing_slack_integration_name  = module.slack_integration.integration_name

  service_catalog = {
    # Replace with your real service → repository mapping.
    # payments      = "appcd-dev/payments"
    # checkout-api  = "appcd-dev/checkout"
    # order-service = "appcd-dev/orders"
  }

  image_namespace_template = "ghcr.io/appcd-dev/{{service}}"
}

module "compliance_auditor" {
  source = "../../modules/aios-agent-compliance-auditor"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
    data_risk_pii = module.policies.policy_ids.data_risk_pii
  }

  existing_aws_integration_name    = module.aws_integration.integration_name
  existing_github_integration_name = module.github_integration.integration_name
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

  existing_slack_integration_name  = module.slack_integration.integration_name
  existing_github_integration_name = module.github_integration.integration_name
}

module "terraform_bot" {
  source = "../../modules/aios-agent-terraform-bot"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  # Self-contained pattern: pass a tenant-level GitHub PAT secret. The module
  # provisions its OWN GitHub + Ubuntu Guild integrations internally, prefixed
  # `terraform-bot-github` / `terraform-bot-ubuntu` so the LLM sees consistent
  # MCP tool names in every SOP. Re-use the `module.github_integration` secret
  # so we keep ONE PAT in Vault for the whole tenant.
  github_secret_id = module.github_integration.secret_id

  # To SHARE the tenant-level integrations (legacy pattern) instead of letting
  # the module provision its own, uncomment these:
  # existing_github_integration_name = module.github_integration.integration_name
  # existing_ubuntu_integration_name = module.ubuntu_integration.integration_name

  # Optional remote runner: set name + remote_runner_attach_to_agent = true
  # remote_runner_name              = "my-org-tofu-runner"
  # remote_runner_attach_to_agent   = true
}

# Use case: SE feedback loop automation.
# Triages `scenario-request` GitHub issues on this repo: matches against
# existing scenarios under examples/scenarios/, or scaffolds a brand-new
# scenario PR (5 files + scripts/demo.sh registry entry), validates with
# tofu fmt + validate, opens the PR, and comments back on the originating
# issue. Self-contained: the module provisions its own
# `scenario-author-github` + `scenario-author-ubuntu` Guild integrations,
# both bound to the same tenant-level PAT secret so `gh` and `git` are
# pre-authed inside the sandbox (no token threading through subagent
# goals — that pattern failed in early traces). See
# modules/aios-agent-scenario-author/README.md and docs/se-feedback.md.
module "scenario_author" {
  source = "../../modules/aios-agent-scenario-author"

  model_names      = module.foundation.model_names
  policy_ids       = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  github_secret_id = module.github_integration.secret_id

  # Defaults: appcd-dev/solutions + scenario-request label.
  # Override repository_full_name for forks or staging tenants.
  # repository_full_name   = "appcd-dev/solutions"
  # scenario_request_label = "scenario-request"
}

module "db_state_splitter" {
  source = "../../modules/aios-agent-db-state-splitter"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  # Self-contained pattern: pass GitHub + AWS PAT secrets and let the module
  # provision its own module-prefixed integrations. Or set
  # `existing_*_integration_name` to share the tenant-level integrations.
  github_secret_id = module.github_integration.secret_id
  aws_secret_id    = module.aws_integration.secret_id

  existing_ubuntu_integration_name = module.ubuntu_integration.integration_name

  # Required: StackGen Consumer MCP attached above. AppStack materialization is mandatory.
  stackgen_mcp_integration_name = sg_guild_integration.stackgen_mcp.name

  enable_github_webhook = false

  # When you run the workflow in Guild, ensure monolith_state_uri is reachable from the
  # Ubuntu integration / remote runner (AWS creds in the Ubuntu shell — not just the AWS
  # MCP tool surface — so `tofu plan -generate-config-out` and `tofu plan` can authenticate.
  # See modules/aios-agent-db-state-splitter/README.md "Operator prerequisites".

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

output "scenario_author_webhook" {
  description = "Webhook endpoint for the Scenario Author bot — wire this into the appcd-dev/solutions repo's GitHub Issues webhook to auto-triage scenario-request issues."
  value = {
    id    = module.scenario_author.webhook_id
    token = module.scenario_author.webhook_token
  }
  sensitive = true
}

output "scenario_author_workflow" {
  description = "Guild workflow name for the SE feedback-loop triage (scenario-request-triage)."
  value       = module.scenario_author.workflow_name
}

output "db_state_splitter_workflows" {
  description = "DB monorepo state split + orphan module authoring workflow names"
  value       = module.db_state_splitter.workflow_names
}

output "cost_optimizer_workflow" {
  description = "Cost optimizer FinOps workflow name (scheduled weekly via cost_optimizer_weekly)."
  value       = module.cost_optimizer.workflow_name
}

output "resource_janitor_workflows" {
  description = "Detection (read-only, scheduled weekly) and cleanup (HITL-gated) workflow names from the resource-janitor module."
  value       = module.resource_janitor.workflow_names
}

output "pipeline_insights_workflow" {
  description = "GitHub pipeline / deployment intelligence workflow name."
  value       = module.pipeline_insights.workflow_name
}

output "release_tracker_workflow" {
  description = "Microservice release-tracking workflow name."
  value       = module.release_tracker.workflow_name
}

output "alert_triage_enabled" {
  description = "Whether the Grafana alert-triage agent + workflow were created (requires grafana_token)."
  value       = length(module.alert_triage) > 0
}
