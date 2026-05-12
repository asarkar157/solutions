terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.10, < 0.2.0" }
  }
}

# =============================================================================
# Multi-Cloud Cost Optimizer Agent Module
# =============================================================================

resource "sg_agent" "cost_optimizer" {
  name        = "cost-optimizer"
  persona     = file("${path.module}/personas/cost-optimizer.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  hitl = { always_allowed = ["web_search", "note", "read_notes"] }

  integrations = compact([
    lookup(var.integration_names, "aws", "") != "" ? var.integration_names.aws : null,
    lookup(var.integration_names, "azure", "") != "" ? var.integration_names.azure : null,
    lookup(var.integration_names, "gcp", "") != "" ? var.integration_names.gcp : null,
    lookup(var.integration_names, "slack", "") != "" ? var.integration_names.slack : null,
  ])
}

resource "sg_agent_budget" "cost_optimizer" {
  agent_name  = sg_agent.cost_optimizer.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.cost_optimizer.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# --- Runbooks ---

resource "sg_runbook_sop" "idle_resource_scan" {
  name        = "idle-resource-scan"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/idle-resource-scan.md", {}))
}

resource "sg_runbook_sop" "rightsizing_analysis" {
  name        = "rightsizing-analysis"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/rightsizing-analysis.md", {}))
}

resource "sg_runbook_sop" "savings_plan_review" {
  name        = "savings-plan-review"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/savings-plan-review.md", {}))
}

resource "sg_runbook_sop" "cost_anomaly_detection" {
  name        = "cost-anomaly-detection"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cost-anomaly-detection.md", {}))
}

# --- Workflow ---

resource "sg_workflow" "finops_review" {
  name        = "finops-review"
  domain      = "finops"
  description = trimspace(templatefile("${path.module}/templates/workflow-finops-review.md", {}))
  approve     = true

  example_queries = [
    "How much are we wasting on idle AWS resources?",
    "Which instances should be rightsized across our cloud accounts?",
    "Are we fully utilizing our reserved instances?",
    "There's a spending spike on Azure — what's causing it?",
    "Generate our monthly FinOps report for leadership",
  ]

  stages = [
    { stage_id = "idle-scan", description = "Detect idle resources across all cloud providers.", required = true },
    { stage_id = "rightsizing", description = "Analyze utilization and recommend instance changes.", required = true },
    { stage_id = "commitment-review", description = "Optimize reserved instance and savings plan coverage.", required = true },
    { stage_id = "anomaly-check", description = "Detect and explain spending anomalies.", required = true },
    { stage_id = "executive-summary", description = "Generate a prioritized savings report with total impact.", required = true },
  ]

  stage_bindings = [
    { stage_id = "idle-scan", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.idle_resource_scan.name], skill_refs = concat(["finops-idle-resource-scan"], try(var.workflow_skill_refs["finops-review::idle-scan"], [])) },
    { stage_id = "rightsizing", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.rightsizing_analysis.name], skill_refs = concat(["finops-rightsizing-analysis"], try(var.workflow_skill_refs["finops-review::rightsizing"], [])) },
    { stage_id = "commitment-review", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.savings_plan_review.name], skill_refs = concat(["finops-commitment-coverage"], try(var.workflow_skill_refs["finops-review::commitment-review"], [])) },
    { stage_id = "anomaly-check", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.cost_anomaly_detection.name], skill_refs = concat(["finops-spend-anomaly"], try(var.workflow_skill_refs["finops-review::anomaly-check"], [])) },
    { stage_id = "executive-summary", agent_ref = sg_agent.cost_optimizer.name, stage_depends_on = ["idle-scan", "rightsizing", "commitment-review", "anomaly-check"], skill_refs = concat(["finops-executive-savings-report"], try(var.workflow_skill_refs["finops-review::executive-summary"], [])) },
  ]
}
