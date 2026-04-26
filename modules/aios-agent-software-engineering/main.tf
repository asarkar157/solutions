terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.0" }
  }
}

# =============================================================================
# Software Engineering Agent Module
# =============================================================================

resource "sg_agent" "linear_planner" {
  name         = "linear-planner-agent"
  persona      = file("${path.module}/personas/linear-planner.md")
  model_names  = [var.model_names.claude_sonnet, var.model_names.gpt4o]
  integrations = compact([lookup(var.integration_names, "linear_mcp", "")])

  hitl = {
    always_allowed = concat(var.linear_readonly_tools, ["linear-integration_create_issue", "web_search", "note", "read_notes"])
  }
}

resource "sg_agent" "cursor_developer" {
  name        = "cursor-developer-agent"
  persona     = file("${path.module}/personas/cursor-developer.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]

  integrations = compact([
    lookup(var.integration_names, "cursor_mcp", ""),
    lookup(var.integration_names, "github", "") != "" ? var.integration_names.github : null,
    lookup(var.integration_names, "slack", "") != "" ? var.integration_names.slack : null,
  ])

  hitl = {
    always_allowed = ["web_search", "cursor-tool_cursor_agents_get_status", "cursor-tool_cursor_agents_get_conversation", "note", "read_notes"]
  }
}

resource "sg_agent_budget" "linear_planner" {
  agent_name  = sg_agent.linear_planner.name
  limit_usd   = 10
  period_type = "daily"
}

resource "sg_agent_budget" "cursor_developer" {
  agent_name  = sg_agent.cursor_developer.name
  limit_usd   = 20
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "planner_dangerous_ops" {
  agent_name = sg_agent.linear_planner.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "developer_dangerous_ops" {
  agent_name = sg_agent.cursor_developer.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "developer_shell_hitl" {
  count      = var.policy_ids.container_shell_hitl != "" ? 1 : 0
  agent_name = sg_agent.cursor_developer.name
  policy_id  = var.policy_ids.container_shell_hitl
  enabled    = true
}

resource "sg_runbook_sop" "linear_ticket_analysis" {
  name        = "linear-ticket-analysis"
  description = "Evaluate Linear ticket and map into technical AC. Steps: 1) Retrieve issue, 2) Extract requirements, 3) Identify implicit technical needs, 4) Update status, 5) Hand off to Cursor Developer Agent."
}

resource "sg_runbook_sop" "cursor_code_authoring" {
  name        = "cursor-code-authoring"
  description = "Use Cursor tool for implementing code changes. Steps: 1) Determine target repo and branch, 2) Launch Cursor agent, 3) Wait for completion via status polling."
}

resource "sg_runbook_sop" "github_pr_submission" {
  name        = "github-pr-submission"
  description = "Submit changes as a PR. Steps: 1) Push branch, 2) Create PR with autoCreatePr, 3) Poll status, 4) Notify #engineering Slack channel."
}

resource "sg_workflow" "feature_development" {
  name        = "feature-development"
  domain      = "software-engineering"
  description = "Full lifecycle code authoring pipeline: Linear ticket → Cursor implementation → GitHub Pull Request."

  required_inputs = ["linear_issue_id", "repository"]
  optional_inputs = ["branch"]

  example_queries = [
    "Start working on ENG-145 in the backend repository",
    "Implement the linear ticket UI-92 targeting the web frontend",
    "Fix bug DB-30 as described in Linear, push PR to data-pipeline repo",
  ]

  stages = [
    { stage_id = "analyze-requirements", description = "Pull product requirements from Linear ticket.", required = true },
    { stage_id = "author-and-test-code", description = "Use Cursor to author features iteratively.", required = true },
    { stage_id = "submit-pull-request", description = "Push and open PR, notify team.", required = true },
  ]

  stage_bindings = [
    { stage_id = "analyze-requirements", agent_ref = sg_agent.linear_planner.name, runbook_refs = [sg_runbook_sop.linear_ticket_analysis.id] },
    { stage_id = "author-and-test-code", agent_ref = sg_agent.cursor_developer.name, stage_depends_on = ["analyze-requirements"], runbook_refs = [sg_runbook_sop.cursor_code_authoring.id] },
    { stage_id = "submit-pull-request", agent_ref = sg_agent.cursor_developer.name, stage_depends_on = ["author-and-test-code"], runbook_refs = [sg_runbook_sop.github_pr_submission.id] },
  ]
}
