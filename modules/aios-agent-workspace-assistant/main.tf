terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  module_prefix = "workspace-assistant"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name      = "workspace-assistant${local.suffix}"
  workflow_name   = "developer-daily-triage${local.suffix}"
  sop_triage_name = "developer-triage-sop${local.suffix}"

  slack_integration_name  = "${local.module_prefix}-slack${local.suffix}"
  linear_integration_name = "${local.module_prefix}-linear${local.suffix}"

  provision_slack  = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""
  provision_linear = trimspace(var.linear_credential_provider_id) != "" && trimspace(var.existing_linear_integration_name) == ""

  resolved_google_integration_name = trimspace(var.existing_google_integration_name)
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_linear_integration_name = trimspace(var.existing_linear_integration_name) != "" ? var.existing_linear_integration_name : (
    local.provision_linear ? module.linear_integration[0].integration_name : ""
  )
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

module "linear_integration" {
  count  = local.provision_linear ? 1 : 0
  source = "../aios-integration-linear"

  integration_name       = local.linear_integration_name
  credential_provider_id = var.linear_credential_provider_id
}

# =============================================================================
# Workspace Assistant Agent Module
# =============================================================================
# Google Workspace + Slack + Linear triage agent for daily developer workflows.

resource "sg_agent" "workspace_assistant" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/workspace-assistant.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = concat(
      var.google_readonly_tools,
      var.linear_readonly_tools,
      local.resolved_slack_integration_name != "" ? [
        "${local.resolved_slack_integration_name}_channels_list",
        "${local.resolved_slack_integration_name}_conversations_history",
      ] : [],
    )
  }

  integrations = compact([
    local.resolved_google_integration_name,
    local.resolved_slack_integration_name,
    local.resolved_linear_integration_name,
  ])
}

resource "sg_agent_policy_attachment" "google_tool_governance" {
  count      = try(var.policy_create_flags.google_tool_governance, true) ? 1 : 0
  agent_name = sg_agent.workspace_assistant.name
  policy_id  = var.policy_ids.google_tool_governance
  enabled    = true
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.workspace_assistant.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_runbook_sop" "developer_triage_sop" {
  name        = local.sop_triage_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/developer-triage-sop.md", {}))
}

resource "sg_workflow" "developer_daily_triage" {
  name        = local.workflow_name
  domain      = "workspace-assistant"
  description = trimspace(templatefile("${path.module}/templates/workflow-developer-daily-triage.md", {}))
  approve     = true

  example_queries = [
    "what are the things pending on my side",
    "what are the works pending for me",
    "triage my work for me",
    "how is my day looking ?",
  ]

  stages = [
    { stage_id = "review-linear", description = "Fetch and analyze active linear tickets.", note = "Find any assigned issues, prioritize by severity.", required = true },
    { stage_id = "review-communications", description = "Analyze unread Slack pings and Gmail inbox.", note = "Cross-reference with Linear.", required = true },
    { stage_id = "generate-brief", description = "Synthesize findings into an actionable priority list.", required = true },
  ]

  stage_bindings = [
    { stage_id = "review-linear", agent_ref = sg_agent.workspace_assistant.name, runbook_refs = [sg_runbook_sop.developer_triage_sop.id], skill_refs = concat(["workspace-linear-triage"], try(var.workflow_skill_refs["developer-daily-triage::review-linear"], [])) },
    { stage_id = "review-communications", agent_ref = sg_agent.workspace_assistant.name, runbook_refs = [sg_runbook_sop.developer_triage_sop.id], skill_refs = concat(["workspace-slack-gmail-digest"], try(var.workflow_skill_refs["developer-daily-triage::review-communications"], [])) },
    { stage_id = "generate-brief", agent_ref = sg_agent.workspace_assistant.name, stage_depends_on = ["review-linear", "review-communications"], runbook_refs = [sg_runbook_sop.developer_triage_sop.id], skill_refs = concat(["workspace-daily-prioritization"], try(var.workflow_skill_refs["developer-daily-triage::generate-brief"], [])) },
  ]
}
