terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.18, < 0.2.0" }
  }
}

locals {
  module_prefix = "gcp-sre"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name           = "gcp-sre${local.suffix}"
  policy_governance_id = "gcp-tool-governance${local.suffix}"

  sop_gke_diag_name  = "gke-cluster-diagnostics${local.suffix}"
  sop_sec_audit_name = "gcp-security-audit${local.suffix}"
  sop_cost_name      = "gcp-cost-analysis${local.suffix}"
  sop_cloud_sql_name = "cloud-sql-health-check${local.suffix}"

  workflow_audit_name    = "gcp-unified-audit${local.suffix}"
  workflow_incident_name = "gke-incident-response${local.suffix}"

  gcp_integration_name = "${local.module_prefix}-gcp${local.suffix}"

  resolved_gcp_integration_name = coalesce(
    trimspace(var.existing_gcp_integration_name) != "" ? var.existing_gcp_integration_name : null,
    try(module.gcp_integration[0].integration_name, null),
    local.gcp_integration_name,
  )
}

module "gcp_integration" {
  count  = trimspace(var.existing_gcp_integration_name) == "" ? 1 : 0
  source = "../aios-integration-gcp"

  integration_name   = local.gcp_integration_name
  existing_secret_id = var.gcp_secret_id
}

# =============================================================================
# GCP SRE Agent Module
# =============================================================================

resource "sg_policy" "gcp_tool_governance" {
  name        = local.policy_governance_id
  description = trimspace(templatefile("${path.module}/templates/policy-gcp-tool-governance.md", {}))
  type        = "logic"
  rego_source = file("${path.module}/policies/gcp-tool-governance.rego")
}

resource "sg_agent" "gcp_sre" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/gcp-sre.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = [
      "${local.resolved_gcp_integration_name}_test_connection",
      "${local.resolved_gcp_integration_name}_execute_command"
    ]
  }

  integrations = [local.resolved_gcp_integration_name]
}

resource "sg_agent_budget" "gcp_sre" {
  agent_name  = sg_agent.gcp_sre.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.gcp_sre.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "gcp_governance" {
  agent_name = sg_agent.gcp_sre.name
  policy_id  = sg_policy.gcp_tool_governance.id
  enabled    = true
}

# --- Runbooks ---

resource "sg_runbook_sop" "gke_diagnostics" {
  name        = local.sop_gke_diag_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/gke-cluster-diagnostics.md", {}))
}

resource "sg_runbook_sop" "gcp_security_audit" {
  name        = local.sop_sec_audit_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/gcp-security-audit.md", {}))
}

resource "sg_runbook_sop" "gcp_cost_analysis" {
  name        = local.sop_cost_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/gcp-cost-analysis.md", {}))
}

resource "sg_runbook_sop" "cloud_sql_health" {
  name        = local.sop_cloud_sql_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cloud-sql-health-check.md", {}))
}

# --- Workflows ---

resource "sg_workflow" "gcp_unified_audit" {
  name        = local.workflow_audit_name
  domain      = "sre-operations"
  description = trimspace(templatefile("${path.module}/templates/workflow-gcp-unified-audit.md", {}))
  approve     = true

  runbook_refs    = [sg_runbook_sop.gcp_security_audit.name, sg_runbook_sop.gcp_cost_analysis.name]
  example_queries = ["Audit our GCP project for security issues", "Find idle GCP resources to save costs", "Check for public Cloud Storage buckets"]

  stages = [
    { stage_id = "security-scan", description = "Identify public buckets, overly permissive IAM, and open firewall rules.", required = true },
    { stage_id = "cost-analysis", description = "Find stopped VMs, unattached disks, and unused IPs.", required = true },
    { stage_id = "consolidate", description = "Generate prioritized findings report.", required = true },
  ]

  stage_bindings = [
    { stage_id = "security-scan", agent_ref = sg_agent.gcp_sre.name, note = "GCP security audit", skill_refs = concat(["gcp-security-posture"], try(var.workflow_skill_refs["${local.workflow_audit_name}::security-scan"], [])) },
    { stage_id = "cost-analysis", agent_ref = sg_agent.gcp_sre.name, note = "GCP cost analysis", skill_refs = concat(["gcp-cost-optimization"], try(var.workflow_skill_refs["${local.workflow_audit_name}::cost-analysis"], [])) },
    { stage_id = "consolidate", agent_ref = sg_agent.gcp_sre.name, stage_depends_on = ["security-scan", "cost-analysis"], note = "Report generation", skill_refs = concat(["gcp-audit-reporting"], try(var.workflow_skill_refs["${local.workflow_audit_name}::consolidate"], [])) },
  ]
}

resource "sg_workflow" "gke_incident_response" {
  name        = local.workflow_incident_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-gke-incident-response.md", {}))
  approve     = true

  triggers        = [{ field = "incident_title_contains", values = ["gke", "gcp", "cloud sql", "cloud run"], type = "passive" }]
  required_inputs = ["cluster_name"]
  optional_inputs = ["namespace", "service_name"]
  runbook_refs    = [sg_runbook_sop.gke_diagnostics.name, sg_runbook_sop.cloud_sql_health.name]

  example_queries = ["GKE pods are crashing in production", "Cloud SQL replication lag is growing", "Cloud Run cold starts are causing timeouts"]

  stages = [
    { stage_id = "diagnose-cluster", description = "Check GKE node and pod health.", required = true },
    { stage_id = "check-dependencies", description = "Verify Cloud SQL and backend service health.", required = true },
    { stage_id = "recommend-action", description = "Recommend remediation based on findings.", required = true },
  ]

  stage_bindings = [
    { stage_id = "diagnose-cluster", agent_ref = sg_agent.gcp_sre.name, runbook_refs = [sg_runbook_sop.gke_diagnostics.name], skill_refs = concat(["gcp-gke-diagnostics"], try(var.workflow_skill_refs["${local.workflow_incident_name}::diagnose-cluster"], [])) },
    { stage_id = "check-dependencies", agent_ref = sg_agent.gcp_sre.name, runbook_refs = [sg_runbook_sop.cloud_sql_health.name], skill_refs = concat(["gcp-cloud-sql-health"], try(var.workflow_skill_refs["${local.workflow_incident_name}::check-dependencies"], [])) },
    { stage_id = "recommend-action", agent_ref = sg_agent.gcp_sre.name, stage_depends_on = ["diagnose-cluster", "check-dependencies"], skill_refs = concat(["gcp-gke-remediation"], try(var.workflow_skill_refs["${local.workflow_incident_name}::recommend-action"], [])) },
  ]
}
