terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  module_prefix = "compliance-auditor"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name               = "compliance-auditor${local.suffix}"
  workflow_assessment_name = "compliance-assessment${local.suffix}"
  policy_data_access_name  = "compliance-data-access${local.suffix}"
  sop_soc2_access_name     = "soc2-access-review${local.suffix}"
  sop_soc2_change_name     = "soc2-change-management${local.suffix}"
  sop_gdpr_data_name       = "gdpr-data-mapping${local.suffix}"
  sop_audit_log_name       = "audit-log-analysis${local.suffix}"
  evidence_assessment_name = "compliance-assessment-evidence${local.suffix}"

  aws_integration_name    = "${local.module_prefix}-aws${local.suffix}"
  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  ubuntu_integration_name = "${local.module_prefix}-ubuntu${local.suffix}"
  sop_cce_compliance_scan = "cce-compliance-repo-scan${local.suffix}"

  provision_aws        = trimspace(var.aws_secret_id) != "" && trimspace(var.existing_aws_integration_name) == ""
  provision_github     = trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) == ""
  provision_ubuntu_cce = var.enable_cce && trimspace(var.existing_ubuntu_integration_name) == "" && (trimspace(var.github_secret_id) != "" || trimspace(var.existing_github_integration_name) != "")

  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_ubuntu_integration_name = trimspace(var.existing_ubuntu_integration_name) != "" ? var.existing_ubuntu_integration_name : (
    local.provision_ubuntu_cce ? module.ubuntu_integration[0].integration_name : ""
  )
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
}

module "cce_scripts" {
  count  = var.enable_cce ? 1 : 0
  source = "../aios-cce-scripts"
}

module "ubuntu_integration" {
  count  = local.provision_ubuntu_cce ? 1 : 0
  source = "../aios-integration-ubuntu"

  integration_name = local.ubuntu_integration_name
  secret_ref_ids   = compact([var.github_secret_id])
  install_tools    = ["gh", "git", "curl", "jq", "cce"]
  env_vars = {
    CCE_PACK_VERSION = module.cce_scripts[0].cce_pack_version
    CCE_PACK_DIR     = module.cce_scripts[0].cce_pack_dir
    CCE_PACK_B64     = module.cce_scripts[0].cce_pack_tarball_b64
    CCE_USE_CASE     = var.cce_use_case
  }
}

# =============================================================================
# Compliance Auditor Agent Module
# =============================================================================

resource "sg_policy" "compliance_data_access" {
  name        = local.policy_data_access_name
  description = trimspace(templatefile("${path.module}/templates/policy-compliance-data-access.md", {}))
  type        = "intervention"
  rego_source = file("${path.module}/policies/compliance-data-access.rego")
}

resource "sg_agent" "compliance_auditor" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/compliance-auditor.md")
  model_names = compact(var.model_names)

  hitl = { always_allowed = ["web_search", "note", "read_notes"] }

  integrations = compact([
    local.resolved_aws_integration_name,
    local.resolved_github_integration_name,
    local.resolved_ubuntu_integration_name,
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
  count      = var.policy_create_flags.data_risk_pii ? 1 : 0
  agent_name = sg_agent.compliance_auditor.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

# --- Runbooks ---

resource "sg_runbook_sop" "soc2_access_review" {
  name        = local.sop_soc2_access_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/soc2-access-review.md", {}))
}

resource "sg_runbook_sop" "soc2_change_management" {
  name        = local.sop_soc2_change_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/soc2-change-management.md", {}))
}

resource "sg_runbook_sop" "gdpr_data_mapping" {
  name        = local.sop_gdpr_data_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/gdpr-data-mapping.md", {}))
}

resource "sg_runbook_sop" "audit_log_analysis" {
  name        = local.sop_audit_log_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/audit-log-analysis.md", {}))
}

resource "sg_runbook_sop" "cce_compliance_repo_scan" {
  count       = var.enable_cce ? 1 : 0
  name        = local.sop_cce_compliance_scan
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/cce-compliance-repo-scan.md.tftpl", {}))
}

resource "sg_evidence_checklist" "compliance_assessment_evidence" {
  name        = local.evidence_assessment_name
  description = "Proof-of-work for SOC2 / change-management / audit-log review stages before publishing a compliance report."
  approve     = true
  required_items = [
    "access_control_sample_evidence",
    "change_management_sample_evidence",
    "audit_log_review_summary",
  ]
  optional_items = ["framework_control_mapping_table"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.72
  }
  metadata = { playbook = "compliance-assessment" }
}

# --- Workflows ---

resource "sg_workflow" "compliance_assessment" {
  name        = local.workflow_assessment_name
  domain      = "compliance"
  description = trimspace(templatefile("${path.module}/templates/workflow-compliance-assessment.md", {}))
  approve     = true

  required_inputs        = ["framework"]
  optional_inputs        = ["scope", "specific_controls"]
  evidence_checklist_ref = sg_evidence_checklist.compliance_assessment_evidence.name

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
    { stage_id = "evidence-quality-gate", description = "LLM evaluates whether collected evidence is sufficient for a passing audit report.", required = false },
    { stage_id = "data-sensitivity-gate", description = "Inline Rego halts the workflow if evidence output contains unredacted PII or high-risk secret material (SSN, payment card, HIPAA identifiers, live API keys, long-lived cloud access key prefixes).", required = true },
    { stage_id = "generate-report", description = "Consolidate findings into a structured compliance report.", required = true },
  ]

  stage_bindings = [
    { stage_id = "access-controls-review", agent_ref = sg_agent.compliance_auditor.name, runbook_refs = [sg_runbook_sop.soc2_access_review.name], skill_refs = concat(["compliance-soc2-access-controls"], try(var.workflow_skill_refs["compliance-assessment::access-controls-review"], [])) },
    { stage_id = "change-management-review", agent_ref = sg_agent.compliance_auditor.name, runbook_refs = compact(concat([sg_runbook_sop.soc2_change_management.name], var.enable_cce ? [sg_runbook_sop.cce_compliance_repo_scan[0].name] : [])), skill_refs = concat(["compliance-change-management-evidence"], var.enable_cce ? [local.sop_cce_compliance_scan] : [], try(var.workflow_skill_refs["compliance-assessment::change-management-review"], [])) },
    { stage_id = "audit-log-review", agent_ref = sg_agent.compliance_auditor.name, runbook_refs = [sg_runbook_sop.audit_log_analysis.name], skill_refs = concat(["compliance-audit-log-review"], try(var.workflow_skill_refs["compliance-assessment::audit-log-review"], [])) },
    # conditional_skip (llm_eval): LLM evaluates whether the evidence collected from the
    # 3 review stages meets SOC2/GDPR audit quality standards. If evidence is sufficient,
    # skip forward to the data-sensitivity scan (never directly to report). If gaps exist,
    # the gate does not match and the workflow continues linearly for human follow-up.
    {
      stage_id         = "evidence-quality-gate"
      action_type      = "conditional_skip"
      stage_depends_on = ["access-controls-review", "change-management-review", "audit-log-review"]
      action_config = {
        condition = "llm_eval"
        match     = "All three review areas (access controls, change management, audit logs) have documented evidence with specific findings, timestamps, and remediation recommendations. No review area is missing or marked as incomplete."
        skip_to   = "data-sensitivity-gate"
        reason    = "LLM-verified: all compliance evidence meets audit quality threshold — continue to PII scan before report generation"
      }
    },
    # policy_check with inline_rego: Deterministic data sensitivity scan.
    # Halts the workflow if evidence output contains PII patterns or common secret material that should
    # have been redacted before report generation (SSN, payment card, HIPAA identifiers, Stripe live keys, AWS access key IDs).
    {
      stage_id         = "data-sensitivity-gate"
      action_type      = "policy_check"
      stage_depends_on = ["evidence-quality-gate"]
      action_config = {
        inline_rego = <<-REGO
          package stage_gate

          import rego.v1

          default allow = true

          # Halt if SSN patterns appear in evidence.
          allow = false if { contains_ssn }
          # Halt if credit card patterns appear.
          allow = false if { contains_cc }
          # Halt if HIPAA patient identifiers appear.
          allow = false if { contains_hipaa }
          # Halt if Stripe live secret key material appears.
          allow = false if { contains_stripe_live }
          # Halt if AWS access key ID prefix appears (20-char AKIA… identifiers).
          allow = false if { contains_aws_access_key_id }

          contains_ssn if { regex.match(`(^|[^0-9])\d{3}-\d{2}-\d{4}([^0-9]|$)`, input.stage_input) }
          contains_cc if { regex.match(`(^|[^0-9])(?:\d{4}[- ]?){3}\d{4}([^0-9]|$)`, input.stage_input) }
          contains_hipaa if { regex.match(`(?i)\b(medical[\s_-]?record|patient[\s_-]?id|mrn)\b`, input.stage_input) }
          contains_stripe_live if { regex.match(`(?i)\bsk_live_[0-9a-zA-Z]{20,}\b`, input.stage_input) }
          contains_aws_access_key_id if { regex.match(`\bAKIA[0-9A-Z]{16}\b`, input.stage_input) }

          deny contains "Evidence contains unredacted SSN pattern — redact before report generation" if { contains_ssn }
          deny contains "Evidence contains unredacted credit card number — redact before report generation" if { contains_cc }
          deny contains "Evidence contains HIPAA patient identifiers — redact before report generation" if { contains_hipaa }
          deny contains "Evidence contains Stripe live secret key material — redact before report generation" if { contains_stripe_live }
          deny contains "Evidence contains AWS access key ID — redact before report generation" if { contains_aws_access_key_id }
        REGO
      }
    },
    { stage_id = "generate-report", agent_ref = sg_agent.compliance_auditor.name, stage_depends_on = ["data-sensitivity-gate"], skill_refs = concat(["compliance-readiness-report"], try(var.workflow_skill_refs["compliance-assessment::generate-report"], [])) },
  ]
}
