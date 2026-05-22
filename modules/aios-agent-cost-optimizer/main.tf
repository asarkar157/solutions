terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.19, < 0.2.0" }
  }
}

locals {
  module_prefix = "cost-optimizer"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name           = "cost-optimizer${local.suffix}"
  workflow_name        = "finops-review${local.suffix}"
  sop_idle_name        = "idle-resource-scan${local.suffix}"
  sop_rightsizing_name = "rightsizing-analysis${local.suffix}"
  sop_savings_name     = "savings-plan-review${local.suffix}"
  sop_anomaly_name     = "cost-anomaly-detection${local.suffix}"
  evidence_name        = "finops-review-evidence${local.suffix}"

  aws_integration_name   = "${local.module_prefix}-aws${local.suffix}"
  azure_integration_name = "${local.module_prefix}-azure${local.suffix}"
  gcp_integration_name   = "${local.module_prefix}-gcp${local.suffix}"
  slack_integration_name = "${local.module_prefix}-slack${local.suffix}"

  provision_aws   = trimspace(var.aws_secret_id) != "" && trimspace(var.existing_aws_integration_name) == ""
  provision_azure = trimspace(var.azure_secret_id) != "" && trimspace(var.existing_azure_integration_name) == ""
  provision_gcp   = trimspace(var.gcp_secret_id) != "" && trimspace(var.existing_gcp_integration_name) == ""
  provision_slack = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""

  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_azure_integration_name = trimspace(var.existing_azure_integration_name) != "" ? var.existing_azure_integration_name : (
    local.provision_azure ? module.azure_integration[0].integration_name : ""
  )
  resolved_gcp_integration_name = trimspace(var.existing_gcp_integration_name) != "" ? var.existing_gcp_integration_name : (
    local.provision_gcp ? module.gcp_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
}

module "azure_integration" {
  count  = local.provision_azure ? 1 : 0
  source = "../aios-integration-azure"

  integration_name   = local.azure_integration_name
  existing_secret_id = var.azure_secret_id
}

module "gcp_integration" {
  count  = local.provision_gcp ? 1 : 0
  source = "../aios-integration-gcp"

  integration_name   = local.gcp_integration_name
  existing_secret_id = var.gcp_secret_id
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

# =============================================================================
# Multi-Cloud Cost Optimizer Agent Module
# =============================================================================

resource "sg_agent" "cost_optimizer" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/cost-optimizer.md")
  model_names = compact(var.model_names)

  hitl = { always_allowed = ["web_search", "note", "read_notes"] }

  integrations = compact([
    local.resolved_aws_integration_name,
    local.resolved_azure_integration_name,
    local.resolved_gcp_integration_name,
    local.resolved_slack_integration_name,
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
  name        = local.sop_idle_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/idle-resource-scan.md", {}))
}

resource "sg_runbook_sop" "rightsizing_analysis" {
  name        = local.sop_rightsizing_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/rightsizing-analysis.md", {}))
}

resource "sg_runbook_sop" "savings_plan_review" {
  name        = local.sop_savings_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/savings-plan-review.md", {}))
}

resource "sg_runbook_sop" "cost_anomaly_detection" {
  name        = local.sop_anomaly_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cost-anomaly-detection.md", {}))
}

resource "sg_evidence_checklist" "finops_review_evidence" {
  name        = local.evidence_name
  description = "Proof-of-work for FinOps review: idle scan, rightsizing, commitments, and anomaly explanations before executive summary."
  approve     = true
  required_items = [
    "idle_resource_findings_documented",
    "rightsizing_recommendations_with_utilization",
    "commitment_coverage_or_gap_analysis",
    "spend_anomaly_hypothesis_with_query_links",
  ]
  optional_items = ["executive_savings_total_estimated"]
  scoring = {
    min_required         = 3
    confidence_threshold = 0.68
  }
  metadata = { playbook = "finops-review" }
}

# --- Workflow ---

resource "sg_workflow" "finops_review" {
  name                   = local.workflow_name
  domain                 = "finops"
  description            = trimspace(templatefile("${path.module}/templates/workflow-finops-review.md", {}))
  approve                = true
  evidence_checklist_ref = sg_evidence_checklist.finops_review_evidence.name

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
    { stage_id = "evidence-review-gate", description = "LLM verifies that all four review areas produced documented findings before the executive summary.", required = true },
    { stage_id = "executive-summary", description = "Generate a prioritized savings report with total impact.", required = true },
  ]

  stage_bindings = [
    { stage_id = "idle-scan", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.idle_resource_scan.name], skill_refs = concat(["finops-idle-resource-scan"], try(var.workflow_skill_refs["finops-review::idle-scan"], [])) },
    { stage_id = "rightsizing", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.rightsizing_analysis.name], skill_refs = concat(["finops-rightsizing-analysis"], try(var.workflow_skill_refs["finops-review::rightsizing"], [])) },
    { stage_id = "commitment-review", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.savings_plan_review.name], skill_refs = concat(["finops-commitment-coverage"], try(var.workflow_skill_refs["finops-review::commitment-review"], [])) },
    { stage_id = "anomaly-check", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.cost_anomaly_detection.name], skill_refs = concat(["finops-spend-anomaly"], try(var.workflow_skill_refs["finops-review::anomaly-check"], [])) },
    # evidence_gate: LLM verifies that all four review areas (idle resources,
    # rightsizing, commitment coverage, anomaly explanations) have documented findings
    # before generating the executive summary.
    {
      stage_id         = "evidence-review-gate"
      action_type      = "evidence_gate"
      stage_depends_on = ["idle-scan", "rightsizing", "commitment-review", "anomaly-check"]
      action_config = {
        confirmation_items = jsonencode([
          "Idle resource findings are documented with resource IDs and estimated savings",
          "Rightsizing recommendations include utilization metrics and target instance types",
          "Commitment coverage or gap analysis is completed with coverage percentages",
          "Spend anomaly hypotheses are documented with supporting query links",
        ])
      }
    },
    { stage_id = "executive-summary", agent_ref = sg_agent.cost_optimizer.name, stage_depends_on = ["evidence-review-gate"], skill_refs = concat(["finops-executive-savings-report"], try(var.workflow_skill_refs["finops-review::executive-summary"], [])) },
  ]
}
