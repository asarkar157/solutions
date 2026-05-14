terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.18, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "pipeline-insights"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name    = "${local.module_prefix}${local.suffix}"
  workflow_name = "github-pipeline-insights${local.suffix}"
  webhook_name  = "slack-pipeline-insights${local.suffix}"

  sop_workflow_run_status_name = "workflow-run-status-lookup${local.suffix}"
  sop_pr_merge_name            = "pr-merge-intelligence${local.suffix}"
  sop_deployment_status_name   = "deployment-status-lookup${local.suffix}"

  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  slack_integration_name  = "${local.module_prefix}-slack${local.suffix}"

  # `provision_github` must be plan-time known (drives `count`). Consumers
  # often forward a computed `github_secret_id` (e.g. `module.github_pat[0].secret_id`)
  # so we don't inspect it here. The inner module surfaces a clear error
  # when both `github_secret_id` and `existing_github_integration_name` are
  # missing. Slack is optional — keeping the secret_id clause preserves the
  # "skip slack entirely when both inputs are blank" semantics that example
  # consumers rely on (passing a static-empty `slack_secret_id` is the
  # documented opt-out path).
  provision_github = trimspace(var.existing_github_integration_name) == ""
  provision_slack  = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
}

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aios-agent-pipeline-insights needs a GitHub Guild integration: provide `github_secret_id` (module provisions one) or `existing_github_integration_name` (module attaches to it)."
    }
  }
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by the ${local.agent_name} agent (read-only Actions/PR/Deployments queries)."
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
  description        = "Slack integration owned by the ${local.agent_name} agent (Slack-mention bridge ingress + replies)."
}

# =============================================================================
# Pipeline & Deployment Intelligence Agent (GitHub-driven, read-only)
# =============================================================================

resource "sg_agent" "pipeline_insights" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/pipeline-insights.md")
  model_names = compact(var.model_names)

  # Read-only by design; allow only the lookup-shaped tools without HITL.
  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }

  integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_slack_integration_name,
  ])
}

resource "sg_agent_budget" "pipeline_insights" {
  agent_name  = sg_agent.pipeline_insights.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.pipeline_insights.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# -----------------------------------------------------------------------------
# Runbooks
# -----------------------------------------------------------------------------

resource "sg_runbook_sop" "workflow_run_status_lookup" {
  name        = local.sop_workflow_run_status_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/workflow-run-status-lookup.md", {}))
}

resource "sg_runbook_sop" "pr_merge_intelligence" {
  name        = local.sop_pr_merge_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/pr-merge-intelligence.md", {}))
}

resource "sg_runbook_sop" "deployment_status_lookup" {
  name    = local.sop_deployment_status_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/deployment-status-lookup.md", {
    deployments_limit = var.deployments_limit
  }))
}

# -----------------------------------------------------------------------------
# Single conversational workflow — handles all three intent classes
# -----------------------------------------------------------------------------

resource "sg_workflow" "pipeline_insights" {
  name        = local.workflow_name
  domain      = "delivery-intelligence"
  description = trimspace(templatefile("${path.module}/templates/workflow-pipeline-insights.md", {}))
  approve     = true

  required_inputs = ["question"]
  optional_inputs = [
    "repository",
    "branch",
    "pull_number",
    "commit_sha",
    "environment",
    "merged_after",
    "limit",
  ]

  example_queries = [
    "Did the latest CI run pass on appcd-dev/solutions main?",
    "Who merged PR #1234 in appcd-dev/solutions and when?",
    "Show me the last 5 production deployments for the payments service",
    "Which workflow is failing on the release/3.0 branch of order-service?",
    "Was the deployment for sha abc123 in checkout-api successful?",
    "List PRs merged into main in appcd-dev/solutions since yesterday",
  ]

  stages = [
    { stage_id = "classify-intent", description = "Decide whether the question is about CI runs, PR merges, deployments, or a combination.", required = true },
    { stage_id = "ci-status", description = "Fetch latest workflow / check-run state for the resolved target.", required = false },
    { stage_id = "pr-merge", description = "Fetch PR merge metadata (who merged, when, mode, scope, reviewers).", required = false },
    { stage_id = "deployment-status", description = "Fetch deployment + deployment_status history for the resolved environment(s).", required = false },
    { stage_id = "compose-answer", description = "Render the linked Markdown response and post to the original channel (or return inline).", required = true },
  ]

  stage_bindings = [
    {
      stage_id   = "classify-intent"
      agent_ref  = sg_agent.pipeline_insights.name
      skill_refs = concat(["github-insights-intent-classification"], try(var.workflow_skill_refs["${local.workflow_name}::classify-intent"], []))
    },
    {
      stage_id         = "ci-status"
      agent_ref        = sg_agent.pipeline_insights.name
      stage_depends_on = ["classify-intent"]
      runbook_refs     = [sg_runbook_sop.workflow_run_status_lookup.name]
      skill_refs       = concat(["github-actions-run-lookup"], try(var.workflow_skill_refs["${local.workflow_name}::ci-status"], []))
    },
    {
      stage_id         = "pr-merge"
      agent_ref        = sg_agent.pipeline_insights.name
      stage_depends_on = ["classify-intent"]
      runbook_refs     = [sg_runbook_sop.pr_merge_intelligence.name]
      skill_refs       = concat(["github-pr-merge-lookup"], try(var.workflow_skill_refs["${local.workflow_name}::pr-merge"], []))
    },
    {
      stage_id         = "deployment-status"
      agent_ref        = sg_agent.pipeline_insights.name
      stage_depends_on = ["classify-intent"]
      runbook_refs     = [sg_runbook_sop.deployment_status_lookup.name]
      skill_refs       = concat(["github-deployment-status-lookup"], try(var.workflow_skill_refs["${local.workflow_name}::deployment-status"], []))
    },
    {
      stage_id         = "compose-answer"
      agent_ref        = sg_agent.pipeline_insights.name
      stage_depends_on = ["ci-status", "pr-merge", "deployment-status"]
      skill_refs       = concat(["github-insights-compose-answer"], try(var.workflow_skill_refs["${local.workflow_name}::compose-answer"], []))
    },
  ]
}

# -----------------------------------------------------------------------------
# Optional Slack webhook ingress — fires the workflow from a Slack mention bridge
# -----------------------------------------------------------------------------

resource "sg_webhook" "slack_pipeline_insights" {
  count       = var.enable_slack_webhook ? 1 : 0
  name        = local.webhook_name
  target_type = "workflow"
  target_name = sg_workflow.pipeline_insights.name
  action      = "A user asked about CI / deployment / PR-merge state in a chat channel. Treat the incoming payload as `question` and resolve the GitHub target before answering."
  enabled     = true
}
