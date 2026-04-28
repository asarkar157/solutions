terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = "~> 0.1.0" }
  }
}

# =============================================================================
# Workspace Assistant Agent Module
# =============================================================================
# Google Workspace + Slack + Linear triage agent for daily developer workflows.

resource "sg_agent" "workspace_assistant" {
  name        = "workspace-assistant"
  persona     = file("${path.module}/personas/workspace-assistant.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]

  hitl = {
    always_allowed = concat(var.google_readonly_tools, var.linear_readonly_tools, [
      "mcp:slack-integration:channels_list",
      "mcp:slack-integration:conversations_history",
      "slack-integration_channels_list",
      "slack-integration_conversations_history"
    ])
  }

  integrations = compact([
    lookup(var.integration_names, "google", "") != "" ? var.integration_names.google : null,
    lookup(var.integration_names, "slack", "") != "" ? var.integration_names.slack : null,
    lookup(var.integration_names, "linear", "") != "" ? var.integration_names.linear : null,
  ])
}

resource "sg_agent_policy_attachment" "google_tool_governance" {
  count      = var.policy_ids.google_tool_governance != "" ? 1 : 0
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
  name        = "developer-triage-sop"
  description = <<-EOT
    Guidelines for synthesizing a daily developer triage report.

    Steps:
    1) Linear: Query the board for any incomplete, high-priority, or blocked issues assigned to the active developer.
    2) Slack: Check unread messages or mentions pointing to escalations, code reviews, or feedback.
    3) Gmail/Drive: Surface any critical external emails or shared docs linked to pending tasks.
    4) Output a unified triage report grouping items by urgency and project area.
  EOT
}

resource "sg_workflow" "developer_daily_triage" {
  name        = "developer-daily-triage"
  domain      = "workspace-assistant"
  description = "A daily triage workflow mapping Linear, Slack, and Gmail context into a structured to-do list."

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
    { stage_id = "review-linear", agent_ref = sg_agent.workspace_assistant.name, runbook_refs = [sg_runbook_sop.developer_triage_sop.id] },
    { stage_id = "review-communications", agent_ref = sg_agent.workspace_assistant.name, runbook_refs = [sg_runbook_sop.developer_triage_sop.id] },
    { stage_id = "generate-brief", agent_ref = sg_agent.workspace_assistant.name, stage_depends_on = ["review-linear", "review-communications"], runbook_refs = [sg_runbook_sop.developer_triage_sop.id] },
  ]
}
