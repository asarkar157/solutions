terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.17, < 0.2.0" }
  }
}

# =============================================================================
# Software Engineering Agent Module
# =============================================================================

resource "sg_agent" "linear_planner" {
  name         = "linear-planner-agent"
  persona      = file("${path.module}/personas/linear-planner.md")
  model_names  = compact(var.model_names)
  integrations = compact([lookup(var.integration_names, "linear_mcp", "")])

  hitl = {
    always_allowed = concat(var.linear_readonly_tools, ["linear-integration_create_issue", "web_search", "note", "read_notes"])
  }
}

resource "sg_agent" "cursor_developer" {
  name        = "cursor-developer-agent"
  persona     = file("${path.module}/personas/cursor-developer.md")
  model_names = compact(var.model_names)

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
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/linear-ticket-analysis.md", {}))
}

resource "sg_runbook_sop" "cursor_code_authoring" {
  name        = "cursor-code-authoring"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cursor-code-authoring.md", {}))
}

resource "sg_runbook_sop" "github_pr_submission" {
  name        = "github-pr-submission"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/github-pr-submission.md", {}))
}

resource "sg_evidence_checklist" "feature_development_evidence" {
  name        = "feature-development-evidence"
  description = "Proof-of-work for Linear-driven feature work: requirements digest, implementation notes, and PR link."
  approve     = true
  required_items = [
    "linear_requirements_summary",
    "implementation_or_test_notes",
    "pull_request_url",
  ]
  optional_items = ["ci_status_or_reviewers_tagged"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.68
  }
  metadata = { playbook = "feature-development" }
}

resource "sg_workflow" "feature_development" {
  name        = "feature-development"
  domain      = "software-engineering"
  description = trimspace(templatefile("${path.module}/templates/workflow-feature-development.md", {}))
  approve     = true

  required_inputs        = ["linear_issue_id", "repository"]
  optional_inputs        = ["branch"]
  evidence_checklist_ref = sg_evidence_checklist.feature_development_evidence.name

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
    { stage_id = "analyze-requirements", agent_ref = sg_agent.linear_planner.name, runbook_refs = [sg_runbook_sop.linear_ticket_analysis.id], skill_refs = concat(["sdlc-linear-requirements"], try(var.workflow_skill_refs["feature-development::analyze-requirements"], [])) },
    { stage_id = "author-and-test-code", agent_ref = sg_agent.cursor_developer.name, stage_depends_on = ["analyze-requirements"], runbook_refs = [sg_runbook_sop.cursor_code_authoring.id], skill_refs = concat(["sdlc-cursor-authoring", "sdlc-local-test-loop"], try(var.workflow_skill_refs["feature-development::author-and-test-code"], [])) },
    { stage_id = "submit-pull-request", agent_ref = sg_agent.cursor_developer.name, stage_depends_on = ["author-and-test-code"], runbook_refs = [sg_runbook_sop.github_pr_submission.id], skill_refs = concat(["sdlc-github-pr-flow"], try(var.workflow_skill_refs["feature-development::submit-pull-request"], [])) },
  ]
}
