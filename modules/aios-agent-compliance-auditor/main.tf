terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.9, < 0.2.0" }
  }
}

# =============================================================================
# Compliance Auditor Agent Module
# =============================================================================

resource "sg_policy" "compliance_data_access" {
  name        = "compliance-data-access"
  description = trimspace(templatefile("${path.module}/templates/policy-compliance-data-access.md", {}))
  type        = "intervention"
  rego_source = file("${path.module}/policies/compliance-data-access.rego")
}

resource "sg_agent" "compliance_auditor" {
  name        = "compliance-auditor"
  persona     = file("${path.module}/personas/compliance-auditor.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  hitl = { always_allowed = ["web_search", "note", "read_notes"] }

  integrations = compact([
    lookup(var.integration_names, "aws", "") != "" ? var.integration_names.aws : null,
    lookup(var.integration_names, "github", "") != "" ? var.integration_names.github : null,
  ])
}

resource "sg_agent_budget" "compliance_auditor" {
  agent_name  = sg_agent.compliance_auditor.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.compliance_auditor.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "data_access" {
  agent_name = sg_agent.compliance_auditor.name
  policy_id  = sg_policy.compliance_data_access.id
  enabled    = true
}

resource "sg_agent_policy_attachment" "data_risk_pii" {
  count      = var.policy_ids.data_risk_pii != "" ? 1 : 0
  agent_name = sg_agent.compliance_auditor.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

# --- Runbooks ---

resource "sg_runbook_sop" "soc2_access_review" {
  name        = "soc2-access-review"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/soc2-access-review.md", {}))
}

resource "sg_runbook_sop" "soc2_change_management" {
  name        = "soc2-change-management"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/soc2-change-management.md", {}))
}

resource "sg_runbook_sop" "gdpr_data_mapping" {
  name        = "gdpr-data-mapping"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/gdpr-data-mapping.md", {}))
}

resource "sg_runbook_sop" "audit_log_analysis" {
  name        = "audit-log-analysis"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/audit-log-analysis.md", {}))
}

# --- Workflows ---

resource "sg_workflow" "compliance_assessment" {
  name        = "compliance-assessment"
  domain      = "compliance"
  description = trimspace(templatefile("${path.module}/templates/workflow-compliance-assessment.md", {}))
  approve     = true

  required_inputs = ["framework"]
  optional_inputs = ["scope", "specific_controls"]

  example_queries = [
    "Run a SOC2 access review on our AWS accounts",
    "Audit our GitHub repos for change management compliance",
    "Map our personal data processing for GDPR Article 30",
    "Check audit logs for suspicious admin activity this week",
    "Are we meeting SOC2 CC6.1 requirements for access controls?",
  ]

  stages = [
    { stage_id = "access-controls-review", description = "Audit IAM, MFA, and privilege management.", required = true },
    { stage_id = "change-management-review", description = "Verify change control and peer review processes.", required = true },
    { stage_id = "audit-log-review", description = "Analyze audit trails for anomalies.", required = true },
    { stage_id = "generate-report", description = "Consolidate findings into a structured compliance report.", required = true },
  ]

  stage_bindings = [
    { stage_id = "access-controls-review", agent_ref = sg_agent.compliance_auditor.name, runbook_refs = [sg_runbook_sop.soc2_access_review.name] },
    { stage_id = "change-management-review", agent_ref = sg_agent.compliance_auditor.name, runbook_refs = [sg_runbook_sop.soc2_change_management.name] },
    { stage_id = "audit-log-review", agent_ref = sg_agent.compliance_auditor.name, runbook_refs = [sg_runbook_sop.audit_log_analysis.name] },
    { stage_id = "generate-report", agent_ref = sg_agent.compliance_auditor.name, stage_depends_on = ["access-controls-review", "change-management-review", "audit-log-review"] },
  ]
}
