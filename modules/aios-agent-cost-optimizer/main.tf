terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.0" }
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
  description = "Multi-cloud idle resource detection. Steps: 1) AWS: Find unattached EBS, stopped EC2, unused EIPs, 2) Azure: Find stopped VMs, unattached disks, 3) GCP: Find stopped instances, unattached persistent disks, 4) Calculate total monthly waste."
}

resource "sg_runbook_sop" "rightsizing_analysis" {
  name        = "rightsizing-analysis"
  description = "Instance rightsizing recommendations. Steps: 1) Collect CPU/memory utilization over 14 days, 2) Identify instances with avg CPU <15% and peak <40%, 3) Map to optimal instance types, 4) Calculate savings per recommendation, 5) Rank by savings potential."
}

resource "sg_runbook_sop" "savings_plan_review" {
  name        = "savings-plan-review"
  description = "Reserved instance and savings plan optimization. Steps: 1) Review current commitments and utilization, 2) Analyze on-demand usage eligible for commitment, 3) Calculate breakeven and payback period, 4) Recommend optimal commitment term and payment option."
}

resource "sg_runbook_sop" "cost_anomaly_detection" {
  name        = "cost-anomaly-detection"
  description = "Detect spending anomalies. Steps: 1) Compare daily/weekly spend against 30-day baseline, 2) Flag services exceeding 2x standard deviation, 3) Correlate spikes with deployment or traffic events, 4) Identify root cause (new resources, config change, traffic spike)."
}

# --- Workflow ---

resource "sg_workflow" "finops_review" {
  name        = "finops-review"
  domain      = "finops"
  description = "Comprehensive multi-cloud FinOps review: idle resources, rightsizing, commitment optimization, and anomaly detection."

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
    { stage_id = "idle-scan", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.idle_resource_scan.name] },
    { stage_id = "rightsizing", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.rightsizing_analysis.name] },
    { stage_id = "commitment-review", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.savings_plan_review.name] },
    { stage_id = "anomaly-check", agent_ref = sg_agent.cost_optimizer.name, runbook_refs = [sg_runbook_sop.cost_anomaly_detection.name] },
    { stage_id = "executive-summary", agent_ref = sg_agent.cost_optimizer.name, stage_depends_on = ["idle-scan", "rightsizing", "commitment-review", "anomaly-check"] },
  ]
}
