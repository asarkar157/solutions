terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

variable "integration_names" {
  type    = map(string)
  default = {}
}

variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "db-performance-tuning::<stage_id>" (gather-metrics, explain-plan, recommend-index). Each value is appended after module defaults.
  EOT
  type        = map(list(string))
  default     = {}
}

resource "sg_agent" "db_optimizer" {
  name        = "db-optimizer"
  persona     = file("${path.module}/personas/db-optimizer.md")
  model_names = compact(var.model_names)
  hitl        = { always_allowed = ["query_db", "explain_plan"] }
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
    {
      stage_id     = "gather-metrics"
      agent_ref    = sg_agent.db_optimizer.name
      runbook_refs = [sg_runbook_sop.slow_query.name]
      skill_refs   = concat(["db-slow-query-telemetry"], try(var.workflow_skill_refs["db-performance-tuning::gather-metrics"], []))
    },
    {
      stage_id         = "explain-plan"
      agent_ref        = sg_agent.db_optimizer.name
      stage_depends_on = ["gather-metrics"]
      skill_refs       = concat(["db-explain-plan-analysis"], try(var.workflow_skill_refs["db-performance-tuning::explain-plan"], []))
    },
    {
      stage_id         = "recommend-index"
      agent_ref        = sg_agent.db_optimizer.name
      stage_depends_on = ["explain-plan"]
      skill_refs       = concat(["db-index-recommendation"], try(var.workflow_skill_refs["db-performance-tuning::recommend-index"], []))
    },
  ]
}
