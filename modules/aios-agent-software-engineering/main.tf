terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  module_prefix = "software-engineering"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_planner_name    = "linear-planner-agent${local.suffix}"
  agent_developer_name  = "cursor-developer-agent${local.suffix}"
  workflow_feature_name = "feature-development${local.suffix}"
  sop_linear_analysis   = "linear-ticket-analysis${local.suffix}"
  sop_cursor_authoring  = "cursor-code-authoring${local.suffix}"
  sop_github_pr         = "github-pr-submission${local.suffix}"
  evidence_feature_name = "feature-development-evidence${local.suffix}"

  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  slack_integration_name  = "${local.module_prefix}-slack${local.suffix}"

  provision_github = trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) == ""
  provision_slack  = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )

  resolved_linear_mcp_integration_name = trimspace(var.existing_linear_mcp_integration_name)
  resolved_cursor_mcp_integration_name = trimspace(var.existing_cursor_mcp_integration_name)
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

# =============================================================================
# Software Engineering Agent Module
# =============================================================================

resource "sg_agent" "linear_planner" {
  name         = local.agent_planner_name
  persona      = file("${path.module}/personas/linear-planner.md")
  model_names  = compact(var.model_names)
  integrations = compact([local.resolved_linear_mcp_integration_name])

  hitl = {
    always_allowed = concat(
      var.linear_readonly_tools,
      ["${local.resolved_linear_mcp_integration_name}_create_issue", "web_search", "note", "read_notes"],
    )
  }
}

resource "sg_agent" "cursor_developer" {
  name        = local.agent_developer_name
  persona     = file("${path.module}/personas/cursor-developer.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_cursor_mcp_integration_name,
    local.resolved_github_integration_name,
    local.resolved_slack_integration_name,
  ])

  hitl = {
    always_allowed = [
      "web_search",
      "${local.resolved_cursor_mcp_integration_name}_cursor_agents_get_status",
      "${local.resolved_cursor_mcp_integration_name}_cursor_agents_get_conversation",
      "note",
      "read_notes",
    ]
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
  count      = try(var.policy_create_flags.container_shell_hitl, true) ? 1 : 0
  agent_name = sg_agent.cursor_developer.name
  policy_id  = var.policy_ids.container_shell_hitl
  enabled    = true
}

resource "sg_runbook_sop" "linear_ticket_analysis" {
  name        = local.sop_linear_analysis
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/linear-ticket-analysis.md", {}))
}

resource "sg_runbook_sop" "cursor_code_authoring" {
  name        = local.sop_cursor_authoring
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cursor-code-authoring.md", {}))
}

resource "sg_runbook_sop" "github_pr_submission" {
  name        = local.sop_github_pr
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/github-pr-submission.md", {}))
}

resource "sg_evidence_checklist" "feature_development_evidence" {
  name        = local.evidence_feature_name
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
  name        = local.workflow_feature_name
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
