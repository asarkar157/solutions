terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", # spawn_contracts / workflow metadata (provider >= 0.1.21).
    version = ">= 0.1.25, < 0.2.0" }
  }
}

# =============================================================================
# Langfuse AI Quality Observer Agent Module
# =============================================================================
# Cross-domain observability agent that combines Langfuse LLM trace analytics
# with optional Grafana infrastructure metrics (and other Guild integrations)
# to produce an AI Operations Health Scorecard.
#
# Real-world scenario: An AI platform team running weekly reliability reviews
# needs automated answers to: Are our agents reliable? Are outputs correct?
# Are costs trending up? Is the infrastructure causing the problems or the
# AI layer? This module provisions the agent, runbooks, and a 5-stage
# workflow. Pass grafana in integration_names for infra correlation; add
# slack, linear, github, etc. for digests, tickets, and deploy context.

locals {
  module_prefix = "langfuse-observer"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  grafana_integration_name = "${local.module_prefix}-grafana${local.suffix}"
  slack_integration_name   = "${local.module_prefix}-slack${local.suffix}"
  github_integration_name  = "${local.module_prefix}-github${local.suffix}"

  provision_grafana = trimspace(var.grafana_secret_id) != "" && trimspace(var.existing_grafana_integration_name) == ""
  provision_slack   = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""
  provision_github  = trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) == ""

  resolved_langfuse_integration_name = trimspace(var.existing_langfuse_integration_name)
  resolved_grafana_integration_name = trimspace(var.existing_grafana_integration_name) != "" ? var.existing_grafana_integration_name : (
    local.provision_grafana ? module.grafana_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )

  has_grafana = local.resolved_grafana_integration_name != ""
  tpl_ctx     = { has_grafana = local.has_grafana }

  observer_integrations = distinct(compact(concat(
    [
      local.resolved_langfuse_integration_name,
      local.resolved_grafana_integration_name,
      local.resolved_slack_integration_name,
      local.resolved_github_integration_name,
    ],
    var.extra_integration_names,
  )))

  default_example_queries = [
    "Run the weekly AI operations health scorecard.",
    "How reliable have our Guild agents been this week?",
    "Are Langfuse error spikes correlated with infrastructure issues in Grafana?",
    "Which agents are producing lower quality outputs and why?",
    "Show me the cost efficiency trends across our AI agent fleet.",
  ]
}

module "grafana_integration" {
  count  = local.provision_grafana ? 1 : 0
  source = "../aios-integration-grafana"

  integration_name   = local.grafana_integration_name
  existing_secret_id = var.grafana_secret_id
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
}

# =============================================================================
# Agent
# =============================================================================

resource "sg_agent" "langfuse_observer" {
  name        = var.agent_name
  persona     = file("${path.module}/personas/langfuse-observer.md")
  model_names = compact(var.model_names)

  integrations = local.observer_integrations
}

resource "sg_agent_budget" "langfuse_observer" {
  agent_name  = sg_agent.langfuse_observer.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

# =============================================================================
# Policy Attachments
# =============================================================================

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.langfuse_observer.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "data_risk" {
  count      = var.policy_ids.data_risk_pii != "" ? 1 : 0
  agent_name = sg_agent.langfuse_observer.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_agent_policy_attachment" "langfuse_observability" {
  count      = var.policy_ids.langfuse_observability != "" ? 1 : 0
  agent_name = sg_agent.langfuse_observer.name
  policy_id  = var.policy_ids.langfuse_observability
  enabled    = true
}

# =============================================================================
# Runbook SOPs
# =============================================================================

resource "sg_runbook_sop" "collect_traces" {
  name        = "${var.runbook_name_prefix}-collect-traces"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-collect-traces.md", {}))
}

resource "sg_runbook_sop" "score_reliability" {
  name        = "${var.runbook_name_prefix}-score-reliability"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-score-reliability.md", {}))
}

resource "sg_runbook_sop" "score_correctness" {
  name        = "${var.runbook_name_prefix}-score-correctness"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-score-correctness.md", {}))
}

resource "sg_runbook_sop" "cross_domain_correlation" {
  # Default prefix keeps the historical name `langfuse-grafana-cross-domain-correlation` for stable state.
  name        = "${var.runbook_name_prefix}-grafana-cross-domain-correlation"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/stage-cross-domain-correlation.md", local.tpl_ctx))
}

# =============================================================================
# Workflow — AI Operations Health Scorecard
# =============================================================================
# 5-stage DAG workflow:
#   collect-traces → score-reliability (parallel with score-correctness)
#                  → cross-domain-correlation (Grafana when present; Langfuse-only otherwise)
#                  → compile-scorecard (synthesis)

resource "sg_workflow" "ai_ops_health_scorecard" {
  name        = var.workflow_name
  domain      = var.workflow_domain
  description = trimspace(templatefile("${path.module}/templates/workflow-description.md", local.tpl_ctx))
  approve     = true


  metadata = {
    planner_max_tool_iterations = "40"
  }
  triggers = [
    { field = "schedule", values = ["weekly", "daily"], type = "passive" },
    { field = "event_type", values = ["reliability.review", "scorecard.requested"], type = "active", source = "guild" },
  ]

  required_inputs = []
  optional_inputs = ["evaluation_window_days", "agent_filter"]

  runbook_refs = [
    sg_runbook_sop.collect_traces.name,
    sg_runbook_sop.score_reliability.name,
    sg_runbook_sop.score_correctness.name,
    sg_runbook_sop.cross_domain_correlation.name,
  ]

  example_queries = concat(local.default_example_queries, var.additional_example_queries)

  stages = [
    {
      stage_id    = "collect-traces"
      description = trimspace(templatefile("${path.module}/templates/runbook-collect-traces.md", {}))
      note        = "Data collection foundation — all subsequent stages depend on this trace dataset."
      required    = true
    },
    {
      stage_id    = "score-reliability"
      description = trimspace(templatefile("${path.module}/templates/runbook-score-reliability.md", {}))
      note        = "Weights: error rate 40%, retry storms 20%, timeouts 20%, error trend 20%."
      required    = true
    },
    {
      stage_id    = "score-correctness"
      description = trimspace(templatefile("${path.module}/templates/runbook-score-correctness.md", {}))
      note        = "Weights: quality distribution 40%, low-quality ratio 25%, consistency 20%, trend 15%."
      required    = true
    },
    {
      stage_id    = "cross-domain-correlation"
      description = trimspace(templatefile("${path.module}/templates/stage-cross-domain-correlation.md", local.tpl_ctx))
      note        = local.has_grafana ? "Joins Langfuse trace data with Grafana infrastructure metrics for root cause attribution." : "Langfuse-focused synthesis; attach Grafana on the module for infrastructure correlation."
      required    = true
    },
    {
      stage_id    = "compile-scorecard"
      description = trimspace(templatefile("${path.module}/templates/stage-compile-scorecard.md", {}))
      note        = "Synthesis stage — produces the final letter-graded scorecard with cross-domain recommendations."
      required    = true
    },
  ]

  stage_bindings = [
    {
      stage_id     = "collect-traces"
      agent_ref    = sg_agent.langfuse_observer.name
      runbook_refs = [sg_runbook_sop.collect_traces.name]
      skill_refs   = concat(["obs-langfuse-collect-traces"], try(var.workflow_skill_refs["${var.workflow_name}::collect-traces"], []))
    },
    {
      stage_id         = "score-reliability"
      agent_ref        = sg_agent.langfuse_observer.name
      stage_depends_on = ["collect-traces"]
      runbook_refs     = [sg_runbook_sop.score_reliability.name]
      skill_refs       = concat(["obs-langfuse-score-reliability"], try(var.workflow_skill_refs["${var.workflow_name}::score-reliability"], []))
    },
    {
      stage_id         = "score-correctness"
      agent_ref        = sg_agent.langfuse_observer.name
      stage_depends_on = ["collect-traces"]
      runbook_refs     = [sg_runbook_sop.score_correctness.name]
      skill_refs       = concat(["obs-langfuse-score-correctness"], try(var.workflow_skill_refs["${var.workflow_name}::score-correctness"], []))
    },
    {
      stage_id         = "cross-domain-correlation"
      agent_ref        = sg_agent.langfuse_observer.name
      stage_depends_on = ["score-reliability", "score-correctness"]
      runbook_refs     = [sg_runbook_sop.cross_domain_correlation.name]
      skill_refs       = concat(["obs-aiops-cross-domain-correlation"], try(var.workflow_skill_refs["${var.workflow_name}::cross-domain-correlation"], []))
    },
    {
      stage_id         = "compile-scorecard"
      agent_ref        = sg_agent.langfuse_observer.name
      stage_depends_on = ["cross-domain-correlation"]
      skill_refs       = concat(["obs-aiops-compile-scorecard"], try(var.workflow_skill_refs["${var.workflow_name}::compile-scorecard"], []))
    },
  ]
}
