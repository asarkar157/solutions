# Compliance evidence factory — scheduled multi-repo CCE pack scan + aggregate digest.

locals {
  workflow_evidence_factory_name = "compliance-evidence-factory${local.suffix}"
  sop_cce_pack_scan              = "cce-compliance-pack-scan${local.suffix}"
  sop_compliance_aggregate       = "compliance-evidence-aggregate${local.suffix}"
  evidence_factory_name          = "compliance-evidence-factory${local.suffix}"

  evidence_factory_enabled = var.enable_cce && var.enable_compliance_evidence_factory
}

resource "terraform_data" "evidence_factory_audit_repos" {
  count = local.evidence_factory_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(var.audit_repo_list) > 0
      error_message = "audit_repo_list must contain at least one org/repo slug when enable_compliance_evidence_factory is true."
    }
  }
}

resource "sg_runbook_sop" "cce_compliance_pack_scan" {
  count   = local.evidence_factory_enabled ? 1 : 0
  name    = local.sop_cce_pack_scan
  approve = true
  description = trimspace(templatefile("${path.module}/templates/cce-compliance-pack-scan.md.tftpl", {
    audit_repo_list_json = jsonencode(var.audit_repo_list)
  }))
}

resource "sg_runbook_sop" "compliance_evidence_aggregate" {
  count       = local.evidence_factory_enabled ? 1 : 0
  name        = local.sop_compliance_aggregate
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/compliance-evidence-aggregate.md.tftpl", {}))
}

resource "sg_evidence_checklist" "compliance_evidence_factory" {
  count       = local.evidence_factory_enabled ? 1 : 0
  name        = local.evidence_factory_name
  description = "Proof-of-work for quarterly compliance evidence factory: multi-repo CCE scans with regulatory touchpoint mapping."
  approve     = true
  required_items = [
    "multi_repo_cce_scan_complete",
    "aggregated_entitlement_summary",
    "regulatory_touchpoint_mapping",
  ]
  optional_items = ["sarif_artifact_path", "quarter_over_quarter_delta"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.75
  }
  metadata = { playbook = "compliance-evidence-factory" }
}

resource "sg_workflow" "compliance_evidence_factory" {
  count       = local.evidence_factory_enabled ? 1 : 0
  name        = local.workflow_evidence_factory_name
  domain      = "compliance"
  description = "Multi-repo CCE security-governance pack scan (audit-evidence, regulatory-scope, landing-zone-governance) with aggregated JSON digest and evidence checklist."
  approve     = true

  required_inputs = []
  optional_inputs = ["audit_quarter", "baseline_artifact_path"]

  evidence_checklist_ref = sg_evidence_checklist.compliance_evidence_factory[0].name

  example_queries = [
    "Run quarterly compliance evidence scan across all application repos",
    "Generate audit evidence for PCI and SOC touchpoints this quarter",
    "Aggregate CCE entitlement reports for landing zone governance review",
  ]

  stages = [
    { stage_id = "multi-repo-cce-pack-scan", description = "Clone audit_repo_list repos; cce-pack-scan.sh run-recipes per repo.", required = true },
    { stage_id = "aggregate-evidence", description = "Merge JSON summaries into compliance-evidence.json digest.", required = true },
    { stage_id = "evidence-checklist-gate", description = "Verify regulatory touchpoints mapped to call sites.", required = true },
    { stage_id = "publish-digest", description = "Publish summary: total call sites, new vs baseline, regulatory touchpoints.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "multi-repo-cce-pack-scan"
      agent_ref    = sg_agent.compliance_auditor.name
      runbook_refs = [sg_runbook_sop.cce_compliance_pack_scan[0].name]
      skill_refs   = concat([local.sop_cce_pack_scan], try(var.workflow_skill_refs["${local.workflow_evidence_factory_name}::multi-repo-cce-pack-scan"], []))
      note         = "For each repo in audit_repo_list: clone on Ubuntu, run cce-pack-scan.sh with audit-evidence, regulatory-scope, landing-zone-governance recipes."
    },
    {
      stage_id         = "aggregate-evidence"
      agent_ref        = sg_agent.compliance_auditor.name
      stage_depends_on = ["multi-repo-cce-pack-scan"]
      runbook_refs     = [sg_runbook_sop.compliance_evidence_aggregate[0].name]
      skill_refs       = concat([local.sop_compliance_aggregate], try(var.workflow_skill_refs["${local.workflow_evidence_factory_name}::aggregate-evidence"], []))
      note             = "Ubuntu: bash $CCE_PACK_DIR/compliance-aggregate.sh — note digest counts only; no per-repo JSON in chat."
    },
    {
      stage_id         = "evidence-checklist-gate"
      action_type      = "evidence_gate"
      stage_depends_on = ["aggregate-evidence"]
      action_config = {
        confirmation_items = jsonencode([
          "Multi-repo CCE scan completed for all audit_repo_list entries",
          "Aggregated entitlement summary with by_provider counts is documented",
          "Regulatory touchpoints (PCI/HIPAA/SOC) mapped to file:line call sites",
        ])
      }
    },
    {
      stage_id         = "publish-digest"
      agent_ref        = sg_agent.compliance_auditor.name
      stage_depends_on = ["evidence-checklist-gate"]
      skill_refs       = try(var.workflow_skill_refs["${local.workflow_evidence_factory_name}::publish-digest"], [])
      note             = "Publish digest from note(compliance_evidence_path) totals — ≤1 paragraph; no entitlement arrays."
    },
  ]
}
