terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.17, < 0.2.0" }
  }
}

# =============================================================================
# GCP SRE Agent Module
# =============================================================================

resource "sg_policy" "gcp_tool_governance" {
  name        = "gcp-tool-governance"
  description = trimspace(templatefile("${path.module}/templates/policy-gcp-tool-governance.md", {}))
  type        = "logic"
  rego_source = file("${path.module}/policies/gcp-tool-governance.rego")
}

resource "sg_agent" "gcp_sre" {
  name        = "gcp-sre"
  persona     = file("${path.module}/personas/gcp-sre.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  hitl = {
    always_allowed = [
      "${var.integration_name}_test_connection",
      "${var.integration_name}_execute_command"
    ]
  }

  integrations = compact([var.integration_name])
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
  name        = "gke-cluster-diagnostics"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/gke-cluster-diagnostics.md", {}))
}

resource "sg_runbook_sop" "gcp_security_audit" {
  name        = "gcp-security-audit"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/gcp-security-audit.md", {}))
}

resource "sg_runbook_sop" "gcp_cost_analysis" {
  name        = "gcp-cost-analysis"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/gcp-cost-analysis.md", {}))
}

resource "sg_runbook_sop" "cloud_sql_health" {
  name        = "cloud-sql-health-check"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cloud-sql-health-check.md", {}))
}

# --- Workflows ---

resource "sg_workflow" "gcp_unified_audit" {
  name        = "gcp-unified-audit"
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
    { stage_id = "security-scan", agent_ref = sg_agent.gcp_sre.name, note = "GCP security audit", skill_refs = concat(["gcp-security-posture"], try(var.workflow_skill_refs["gcp-unified-audit::security-scan"], [])) },
    { stage_id = "cost-analysis", agent_ref = sg_agent.gcp_sre.name, note = "GCP cost analysis", skill_refs = concat(["gcp-cost-optimization"], try(var.workflow_skill_refs["gcp-unified-audit::cost-analysis"], [])) },
    { stage_id = "consolidate", agent_ref = sg_agent.gcp_sre.name, stage_depends_on = ["security-scan", "cost-analysis"], note = "Report generation", skill_refs = concat(["gcp-audit-reporting"], try(var.workflow_skill_refs["gcp-unified-audit::consolidate"], [])) },
  ]
}

resource "sg_workflow" "gke_incident_response" {
  name        = "gke-incident-response"
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
    { stage_id = "diagnose-cluster", agent_ref = sg_agent.gcp_sre.name, runbook_refs = [sg_runbook_sop.gke_diagnostics.name], skill_refs = concat(["gcp-gke-diagnostics"], try(var.workflow_skill_refs["gke-incident-response::diagnose-cluster"], [])) },
    { stage_id = "check-dependencies", agent_ref = sg_agent.gcp_sre.name, runbook_refs = [sg_runbook_sop.cloud_sql_health.name], skill_refs = concat(["gcp-cloud-sql-health"], try(var.workflow_skill_refs["gke-incident-response::check-dependencies"], [])) },
    { stage_id = "recommend-action", agent_ref = sg_agent.gcp_sre.name, stage_depends_on = ["diagnose-cluster", "check-dependencies"], skill_refs = concat(["gcp-gke-remediation"], try(var.workflow_skill_refs["gke-incident-response::recommend-action"], [])) },
  ]
}
