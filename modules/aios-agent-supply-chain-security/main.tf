terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.13, < 0.2.0" }
  }
}

# =============================================================================
# Supply Chain Security Agent Module
# =============================================================================

locals {
  github_integration_attached = var.github_integration_name != "" ? var.github_integration_name : (var.github_token != "" ? "github-integration" : "")
}

resource "sg_policy" "npm_integrity_check" {
  name        = "npm-integrity-check"
  description = trimspace(templatefile("${path.module}/templates/policy-npm-integrity-check.md", {}))
  type        = "intervention"
  rego_source = file("${path.module}/policies/npm-integrity-check.rego")
}

resource "sg_policy" "npm_sandbox_network" {
  name        = "npm-sandbox-network"
  description = trimspace(templatefile("${path.module}/templates/policy-npm-sandbox-network.md", {}))
  type        = "intervention"
  rego_source = file("${path.module}/policies/npm-sandbox-network.rego")
}

resource "sg_policy" "phantom_dependency" {
  name        = "phantom-dependency-detection"
  description = trimspace(templatefile("${path.module}/templates/policy-phantom-dependency-detection.md", {}))
  type        = "intervention"
  rego_source = file("${path.module}/policies/phantom-dependency-detection.rego")
}

resource "sg_agent" "supply_chain_analyst" {
  name        = "supply-chain-security-analyst"
  persona     = file("${path.module}/personas/supply-chain-security.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]

  hitl = { always_allowed = ["github-integration_test_connection"] }

  integrations = local.github_integration_attached != "" ? [local.github_integration_attached] : []
}

resource "sg_agent_budget" "supply_chain" {
  agent_name  = sg_agent.supply_chain_analyst.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.supply_chain_analyst.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "npm_integrity" {
  agent_name = sg_agent.supply_chain_analyst.name
  policy_id  = sg_policy.npm_integrity_check.id
  enabled    = true
}

resource "sg_agent_policy_attachment" "npm_sandbox" {
  agent_name = sg_agent.supply_chain_analyst.name
  policy_id  = sg_policy.npm_sandbox_network.id
  enabled    = true
}

resource "sg_agent_policy_attachment" "phantom_dep" {
  agent_name = sg_agent.supply_chain_analyst.name
  policy_id  = sg_policy.phantom_dependency.id
  enabled    = true
}

resource "sg_runbook_sop" "npm_integrity_check" {
  name        = "npm-integrity-check"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-npm-integrity-check.md", {}))
}

resource "sg_runbook_sop" "npm_behavioral_sandbox" {
  name        = "npm-behavioral-sandbox"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-npm-behavioral-sandbox.md", {}))
}

resource "sg_runbook_sop" "npm_manifest_anomaly" {
  name        = "npm-manifest-anomaly-scan"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-npm-manifest-anomaly-scan.md", {}))
}

resource "sg_remediation_pattern" "block_unverified_package" {
  name              = "block-unverified-package"
  description       = trimspace(templatefile("${path.module}/templates/remediation-block-unverified-package.md", {}))
  version           = 1
  risk_level        = "medium"
  blast_radius      = "single-repo"
  requires_approval = true
  approve           = true
}

resource "sg_remediation_pattern" "quarantine_phantom" {
  name              = "quarantine-phantom-dependency"
  description       = trimspace(templatefile("${path.module}/templates/remediation-quarantine-phantom-dependency.md", {}))
  version           = 1
  risk_level        = "medium"
  blast_radius      = "single-repo"
  requires_approval = true
  approve           = true
}

resource "sg_evidence_checklist" "supply_chain_incident" {
  name        = "supply-chain-incident-evidence"
  description = trimspace(templatefile("${path.module}/templates/evidence-supply-chain-incident-body.md", {}))
  version     = 1
  approve     = true
  required_items = [
    "npm_audit_or_provenance_report_linked",
    "sandbox_run_log_or_summary",
    "dependency_graph_delta_captured",
  ]
  optional_items = ["github_advisory_cross_reference"]
  scoring {
    min_required         = 2
    confidence_threshold = 0.7
  }
  metadata = { playbook = "supply-chain-security" }
}

resource "sg_workflow" "supply_chain_scan" {
  name        = "supply-chain-security-analyst"
  domain      = "security"
  description = trimspace(templatefile("${path.module}/templates/workflow-supply-chain-security-analyst.md", {}))
  approve     = true

  triggers = [
    { field = "incident_title_contains", values = ["supply chain", "npm", "malicious package", "provenance"], type = "passive" },
  ]

  required_inputs        = ["github_org"]
  optional_inputs        = ["repo_name", "package_name", "severity"]
  evidence_checklist_ref = sg_evidence_checklist.supply_chain_incident.name

  example_queries = [
    "Check if our npm packages have valid SLSA provenance",
    "Scan our GitHub org for supply chain vulnerabilities",
    "Are there any phantom dependencies in our repositories?",
  ]

  stages = [
    { stage_id = "integrity-check", description = "Check npm audit signatures and OIDC/SLSA provenance.", required = true },
    { stage_id = "behavioral-sandbox", description = "Sandbox install flagged packages and monitor.", required = true },
    { stage_id = "manifest-anomaly", description = "Compare declared vs actual imports.", required = true },
    { stage_id = "correlate", description = "Cross-reference all findings.", required = true },
    { stage_id = "recommend", description = "Recommend remediation.", required = true },
  ]

  stage_bindings = [
    { stage_id = "integrity-check", agent_ref = sg_agent.supply_chain_analyst.name, runbook_refs = [sg_runbook_sop.npm_integrity_check.name], skill_refs = concat(["supply-chain-npm-integrity"], try(var.workflow_skill_refs["supply-chain-security-analyst::integrity-check"], [])) },
    { stage_id = "behavioral-sandbox", agent_ref = sg_agent.supply_chain_analyst.name, runbook_refs = [sg_runbook_sop.npm_behavioral_sandbox.name], skill_refs = concat(["supply-chain-npm-sandbox"], try(var.workflow_skill_refs["supply-chain-security-analyst::behavioral-sandbox"], [])) },
    { stage_id = "manifest-anomaly", agent_ref = sg_agent.supply_chain_analyst.name, runbook_refs = [sg_runbook_sop.npm_manifest_anomaly.name], skill_refs = concat(["supply-chain-manifest-anomaly"], try(var.workflow_skill_refs["supply-chain-security-analyst::manifest-anomaly"], [])) },
    { stage_id = "correlate", agent_ref = sg_agent.supply_chain_analyst.name, stage_depends_on = ["integrity-check", "behavioral-sandbox", "manifest-anomaly"], skill_refs = concat(["supply-chain-correlation"], try(var.workflow_skill_refs["supply-chain-security-analyst::correlate"], [])) },
    { stage_id = "recommend", agent_ref = sg_agent.supply_chain_analyst.name, stage_depends_on = ["correlate"], skill_refs = concat(["supply-chain-remediation-guidance"], try(var.workflow_skill_refs["supply-chain-security-analyst::recommend"], [])) },
  ]
}
