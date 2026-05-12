terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.9, < 0.2.0" }
  }
}

variable "integration_names" {
  type    = map(string)
  default = {}
}

variable "model_names" {
  type = map(string)
}

resource "sg_agent" "db_optimizer" {
  name    = "db-optimizer"
  persona = file("${path.module}/personas/db-optimizer.md")
  model_names = compact([
    lookup(var.model_names, "gpt4o", ""),
    lookup(var.model_names, "claude_sonnet", ""),
    lookup(var.model_names, "gemini_flash", "")
  ])
  hitl = { always_allowed = ["query_db", "explain_plan"] }
  integrations = compact([
    lookup(var.integration_names, "datadog", ""),
    lookup(var.integration_names, "slack", ""),
  ])
}

resource "sg_runbook_sop" "slow_query" {
  name        = "slow-query-analysis"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/slow-query-analysis.md", {}))
}

resource "sg_workflow" "db_tuning" {
  name        = "db-performance-tuning"
  domain      = "sre"
  description = "Analyze database telemetry, identify slow queries, and recommend indexing or refactoring."
  approve     = true

  stages = [
    { stage_id = "gather-metrics", description = "Fetch slow query logs and telemetry.", required = true },
    { stage_id = "explain-plan", description = "Run EXPLAIN on the slowest queries.", required = true },
    { stage_id = "recommend-index", description = "Draft indexing recommendations.", required = true },
  ]

  stage_bindings = [
    { stage_id = "gather-metrics", agent_ref = sg_agent.db_optimizer.name, runbook_refs = [sg_runbook_sop.slow_query.name] },
    { stage_id = "explain-plan", agent_ref = sg_agent.db_optimizer.name, stage_depends_on = ["gather-metrics"] },
    { stage_id = "recommend-index", agent_ref = sg_agent.db_optimizer.name, stage_depends_on = ["explain-plan"] },
  ]
}
