terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

# =============================================================================
# Pipeline & Deployment Intelligence Agent (GitHub-driven, read-only)
# =============================================================================

resource "sg_agent" "pipeline_insights" {
  name        = "pipeline-insights"
  persona     = file("${path.module}/personas/pipeline-insights.md")
  model_names = compact(var.model_names)

  # Read-only by design; allow only the lookup-shaped tools without HITL.
  hitl = {
    always_allowed = ["web_search", "note", "read_notes"]
  }

  integrations = compact([
    lookup(var.integration_names, "github", ""),
    lookup(var.integration_names, "slack", ""),
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
  name        = "workflow-run-status-lookup"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/workflow-run-status-lookup.md", {}))
}

resource "sg_runbook_sop" "pr_merge_intelligence" {
  name        = "pr-merge-intelligence"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/pr-merge-intelligence.md", {}))
}

resource "sg_runbook_sop" "deployment_status_lookup" {
  name    = "deployment-status-lookup"
  approve = true
  description = trimspace(templatefile("${path.module}/templates/deployment-status-lookup.md", {
    deployments_limit = var.deployments_limit
  }))
}

# -----------------------------------------------------------------------------
# Single conversational workflow — handles all three intent classes
# -----------------------------------------------------------------------------

resource "sg_workflow" "pipeline_insights" {
  name        = "github-pipeline-insights"
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
      skill_refs = concat(["github-insights-intent-classification"], try(var.workflow_skill_refs["github-pipeline-insights::classify-intent"], []))
    },
    {
      stage_id         = "ci-status"
      agent_ref        = sg_agent.pipeline_insights.name
      stage_depends_on = ["classify-intent"]
      runbook_refs     = [sg_runbook_sop.workflow_run_status_lookup.name]
      skill_refs       = concat(["github-actions-run-lookup"], try(var.workflow_skill_refs["github-pipeline-insights::ci-status"], []))
    },
    {
      stage_id         = "pr-merge"
      agent_ref        = sg_agent.pipeline_insights.name
      stage_depends_on = ["classify-intent"]
      runbook_refs     = [sg_runbook_sop.pr_merge_intelligence.name]
      skill_refs       = concat(["github-pr-merge-lookup"], try(var.workflow_skill_refs["github-pipeline-insights::pr-merge"], []))
    },
    {
      stage_id         = "deployment-status"
      agent_ref        = sg_agent.pipeline_insights.name
      stage_depends_on = ["classify-intent"]
      runbook_refs     = [sg_runbook_sop.deployment_status_lookup.name]
      skill_refs       = concat(["github-deployment-status-lookup"], try(var.workflow_skill_refs["github-pipeline-insights::deployment-status"], []))
    },
    {
      stage_id         = "compose-answer"
      agent_ref        = sg_agent.pipeline_insights.name
      stage_depends_on = ["ci-status", "pr-merge", "deployment-status"]
      skill_refs       = concat(["github-insights-compose-answer"], try(var.workflow_skill_refs["github-pipeline-insights::compose-answer"], []))
    },
  ]
}

# -----------------------------------------------------------------------------
# Optional Slack webhook ingress — fires the workflow from a Slack mention bridge
# -----------------------------------------------------------------------------

resource "sg_webhook" "slack_pipeline_insights" {
  count       = var.enable_slack_webhook ? 1 : 0
  name        = "slack-pipeline-insights"
  target_type = "workflow"
  target_name = sg_workflow.pipeline_insights.name
  action      = "A user asked about CI / deployment / PR-merge state in a chat channel. Treat the incoming payload as `question` and resolve the GitHub target before answering."
  enabled     = true
}
