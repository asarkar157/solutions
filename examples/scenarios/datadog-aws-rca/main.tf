# =============================================================================
# Scenario: datadog-aws-rca
# =============================================================================
# Pre-sales pitch: "A Datadog monitor fires at 2am — what does your thing do?"
# Datadog alert -> Aiden investigates on AWS -> writes the RCA back to Datadog
# -> opens a GitHub fix PR (policy-gated) — plus a weekly FinOps review for the
# cost wow factor. The alert ingest, investigation, and RCA UI live in the
# stackgen-sre-app (installed separately); this root provisions policy
# guardrails and attaches GitHub (and optional AWS / Slack) to the SRE app.
# Datadog is expected from SRE app onboarding (data.sg_app + data.sg_guild_integration).
# Does not register LLM models — the SRE app install owns investigator model wiring.
#
# See ./README.md for the talk track and the manual stackgen-sre-app + Datadog
# webhook wiring steps.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.27, < 0.2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }
}

# Referenced transitively by aios-agent-cost-optimizer (disabled when enable_finops = false).
provider "azurerm" {
  features {}
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
  insecure       = var.stackgen_insecure
}

# SRE app install — read integrations already bound during onboarding (e.g. datadog).
data "sg_app" "sre" {
  app_name = var.sre_app_name
}

# Existing Datadog integration from SRE app setup (default name "datadog").
data "sg_guild_integration" "datadog" {
  name = var.existing_datadog_integration_name
}

locals {
  enable_aws = trimspace(var.aws_role_arn) != ""

  datadog_integration_name = data.sg_guild_integration.datadog.name

  runner_typed_secret_refs = var.create_remote_runner ? merge(
    { github = module.github_integration.secret_id },
    local.enable_aws ? { aws = module.aws_integration[0].secret_id } : {},
  ) : {}

  # Docker cannot reach host localhost:8088 — use host.docker.internal on macOS/Linux dev-edge.
  runner_mothership_url = (
    var.stackgen_insecure && can(regex("localhost|127\\.0\\.0\\.1", var.stackgen_url))
    ? replace(replace(var.stackgen_url, "localhost", "host.docker.internal"), "127.0.0.1", "host.docker.internal")
    : var.stackgen_url
  )

  remote_runner_docker_run_command = var.create_remote_runner ? trimspace(join(" ", compact([
    "docker run -d",
    "--name ${module.remote_runner[0].runner_name}",
    "--restart unless-stopped",
    var.stackgen_insecure && can(regex("localhost|127\\.0\\.0\\.1", var.stackgen_url)) ? "--add-host=host.docker.internal:host-gateway" : "",
    var.runner_docker_image,
    "--runner-token", module.remote_runner[0].runner_token,
    "--mothership", local.runner_mothership_url,
    "--auto-discover",
    module.remote_runner[0].sync_cli_args,
  ]))) : ""

  sre_app_new_integration_names = compact([
    module.github_integration.integration_name,
    local.enable_aws ? module.aws_integration[0].integration_name : "",
    length(module.slack_integration) > 0 ? module.slack_integration[0].integration_name : "",
  ])

  sre_app_service_repo_config = {
    for svc, repo in var.service_repository_map :
    "service_repo_${svc}" => repo
  }
}

# Layer 0 — optional guardrails (skip when org already has policies).
module "policies" {
  count  = var.enable_policies ? 1 : 0
  source = "../../../modules/aios-policies"
}

# -----------------------------------------------------------------------------
# Layer 1 — integrations this scenario creates (Datadog comes from SRE onboarding).
# -----------------------------------------------------------------------------

# AWS MCP integration: optional cloud investigation target.
module "aws_integration" {
  count  = local.enable_aws ? 1 : 0
  source = "../../../modules/aios-integration-aws"

  aws_role_arn = var.aws_role_arn
  aws_region   = var.aws_region
}

# GitHub SCM integration with `repo` scope: discovery context AND the fix-PR the
# investigator opens from the RCA. Required for this scenario.
module "github_integration" {
  source = "../../../modules/aios-integration-github"

  github_token = var.github_token
}

# Slack (optional): incident channel + approval prompts + FinOps summary.
module "slack_integration" {
  count  = trimspace(var.slack_bot_token) != "" ? 1 : 0
  source = "../../../modules/aios-integration-slack"

  slack_bot_token = var.slack_bot_token
}

# Layer 1c — remote runner for in-VPC / shell tools during investigations.
module "remote_runner" {
  count  = var.create_remote_runner ? 1 : 0
  source = "../../../modules/aios-remote-runner"

  create_runner     = var.register_remote_runner
  name              = var.remote_runner_name
  description       = "On-prem shell runner for ${var.investigator_agent_name} (Datadog/AWS/GitHub diagnostics)."
  typed_secret_refs = local.runner_typed_secret_refs
  labels = {
    "stackgen.app" = "sre"
  }
}

# Layer 1b — merge GitHub (and optional AWS / Slack) onto the SRE app install;
# optional investigator policy attachments and remote runner merge.
module "sre_app_bindings" {
  count  = var.enable_sre_app_bindings ? 1 : 0
  source = "../../../modules/aios-sre-app-bindings"

  merge_existing_app_integrations = true
  enable_discovery_bootstrap      = false

  integration_names = local.sre_app_new_integration_names
  config            = local.sre_app_service_repo_config

  alert_webhooks = var.enable_datadog_alert_webhook ? [{
    source           = "datadog"
    integration      = local.datadog_integration_name
    auto_investigate = var.datadog_alert_auto_investigate
  }] : []

  remote_runner_name = var.create_remote_runner ? module.remote_runner[0].runner_name : ""

  investigator_policy_ids = var.enable_policies ? {
    dangerous_ops                = module.policies[0].policy_ids.dangerous_ops
    sre_remediation              = module.policies[0].policy_ids.sre_remediation
    prod_write_gate              = module.policies[0].policy_ids.prod_write_gate
    sre_investigation_write_gate = module.policies[0].policy_ids.sre_investigation_write_gate
    pagerduty_escalation_gate    = module.policies[0].policy_ids.pagerduty_escalation_gate
  } : null
  policy_create_flags = var.enable_policies ? module.policies[0].policy_create_flags : null
}

# -----------------------------------------------------------------------------
# Layer 2 — Cost management wow factor (FinOps review + weekly cron).
# -----------------------------------------------------------------------------
module "cost_optimizer" {
  count  = var.enable_finops ? 1 : 0
  source = "../../../modules/aios-agent-cost-optimizer"

  model_names = var.finops_model_names
  policy_ids  = { dangerous_ops = module.policies[0].policy_ids.dangerous_ops }

  existing_aws_integration_name   = local.enable_aws ? module.aws_integration[0].integration_name : ""
  existing_slack_integration_name = length(module.slack_integration) > 0 ? module.slack_integration[0].integration_name : ""
}

check "finops_requires_policies" {
  assert {
    condition     = !var.enable_finops || var.enable_policies
    error_message = "enable_finops requires enable_policies = true (FinOps agent needs dangerous_ops policy)."
  }
}

module "weekly_finops_schedule" {
  count  = var.enable_finops ? 1 : 0
  source = "../../../modules/aios-agent-schedules"

  target_type = "workflow"
  target_name = module.cost_optimizer[0].workflow_name

  schedules = [
    {
      name       = "weekly-finops-review"
      expression = "0 9 * * 1" # Mondays 09:00 UTC
      action     = "Run the full FinOps review across the connected AWS account: idle scan, rightsizing, commitment review, anomaly check, then post the executive summary (with savings totals) to Slack."
    },
  ]
}
