terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", # spawn_contracts / workflow metadata (provider >= 0.1.21).
    version = ">= 0.1.25, < 0.2.0" }
  }
}

# =============================================================================
# Supply Chain Security Agent Module
# =============================================================================

locals {
  module_prefix = "supply-chain-security"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name    = "supply-chain-security-analyst${local.suffix}"
  workflow_name = "supply-chain-security-analyst${local.suffix}"

  sop_npm_integrity_name        = "npm-integrity-check${local.suffix}"
  sop_npm_sandbox_name          = "npm-behavioral-sandbox${local.suffix}"
  sop_npm_manifest_name         = "npm-manifest-anomaly-scan${local.suffix}"
  sop_correlation_name          = "supply-chain-correlation${local.suffix}"
  sop_remediation_guidance_name = "supply-chain-remediation-guidance${local.suffix}"
  policy_npm_integrity_name     = "npm-integrity-check${local.suffix}"
  policy_npm_sandbox_name       = "npm-sandbox-network${local.suffix}"
  policy_phantom_name           = "phantom-dependency-detection${local.suffix}"
  remediation_block_name        = "block-unverified-package${local.suffix}"
  remediation_quarantine_name   = "quarantine-phantom-dependency${local.suffix}"
  evidence_name                 = "supply-chain-incident-evidence${local.suffix}"

  github_integration_name = "${local.module_prefix}-github${local.suffix}"

  # `provision_github` must be plan-time known because it drives `count` on
  # the nested integration module. We don't inspect `var.github_secret_id`
  # here — consumers often forward it from another module's output (e.g.
  # `module.github_pat[0].secret_id`) which is only resolved at apply time.
  # The inner aios-integration-github module's precondition surfaces a clear
  # error when both inputs are missing.
  provision_github = trimspace(var.existing_github_integration_name) == ""

  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )

  github_tool_prefix = local.resolved_github_integration_name
}

resource "terraform_data" "github_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_github_integration_name) != ""
      error_message = "aios-agent-supply-chain-security needs a GitHub Guild integration: provide `github_secret_id` (module provisions one) or `existing_github_integration_name`."
    }
  }
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
  description        = "GitHub integration owned by the ${local.agent_name} agent (org / repo / package / advisory queries)."
}

resource "sg_policy" "npm_integrity_check" {
  name        = local.policy_npm_integrity_name
  description = trimspace(templatefile("${path.module}/templates/policy-npm-integrity-check.md", {}))
  type        = "intervention"
  rego_source = file("${path.module}/policies/npm-integrity-check.rego")
}

resource "sg_policy" "npm_sandbox_network" {
  name        = local.policy_npm_sandbox_name
  description = trimspace(templatefile("${path.module}/templates/policy-npm-sandbox-network.md", {}))
  type        = "intervention"
  rego_source = file("${path.module}/policies/npm-sandbox-network.rego")
}

resource "sg_policy" "phantom_dependency" {
  name        = local.policy_phantom_name
  description = trimspace(templatefile("${path.module}/templates/policy-phantom-dependency-detection.md", {}))
  type        = "intervention"
  rego_source = file("${path.module}/policies/phantom-dependency-detection.rego")
}

resource "sg_agent" "supply_chain_analyst" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/supply-chain-security.md")
  model_names = compact(var.model_names)

  hitl = { always_allowed = ["${local.github_tool_prefix}_test_connection"] }

  integrations = compact([
    local.resolved_github_integration_name,
    local.resolved_ubuntu_integration_name,
  ])
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
  name        = local.sop_npm_integrity_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-npm-integrity-check.md", {}))
}

resource "sg_runbook_sop" "npm_behavioral_sandbox" {
  name        = local.sop_npm_sandbox_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-npm-behavioral-sandbox.md", {}))
}

resource "sg_runbook_sop" "npm_manifest_anomaly" {
  name        = local.sop_npm_manifest_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-npm-manifest-anomaly-scan.md", {}))
}

resource "sg_runbook_sop" "supply_chain_correlation" {
  name        = local.sop_correlation_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-supply-chain-correlation.md", {}))
}

resource "sg_runbook_sop" "supply_chain_remediation_guidance" {
  name        = local.sop_remediation_guidance_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-supply-chain-remediation-guidance.md", {}))
}

resource "sg_remediation_pattern" "block_unverified_package" {
  name              = local.remediation_block_name
  description       = trimspace(templatefile("${path.module}/templates/remediation-block-unverified-package.md", {}))
  risk_level        = "medium"
  blast_radius      = "single-repo"
  requires_approval = true
  approve           = true
}

resource "sg_remediation_pattern" "quarantine_phantom" {
  name              = local.remediation_quarantine_name
  description       = trimspace(templatefile("${path.module}/templates/remediation-quarantine-phantom-dependency.md", {}))
  risk_level        = "medium"
  blast_radius      = "single-repo"
  requires_approval = true
  approve           = true
}

resource "sg_evidence_checklist" "supply_chain_incident" {
  name        = local.evidence_name
  description = trimspace(templatefile("${path.module}/templates/evidence-supply-chain-incident-body.md", {}))
  approve     = true
  required_items = [
    "npm_audit_or_provenance_report_linked",
    "sandbox_run_log_or_summary",
    "dependency_graph_delta_captured",
  ]
  optional_items = ["github_advisory_cross_reference"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.7
  }
  metadata = { playbook = "supply-chain-security" }
}

resource "sg_workflow" "supply_chain_scan" {
  name        = local.workflow_name
  domain      = "security"
  description = trimspace(templatefile("${path.module}/templates/workflow-supply-chain-security-analyst.md", {}))
  approve     = true


  metadata = {
    planner_max_tool_iterations = "40"
  }
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
    { stage_id = "cce-cve-reachability", description = "CCE f-SBOM: prioritize CVEs with reachable call sites.", required = false },
    { stage_id = "cce-cve-skip-fix", description = "Skip CVE fix LLM when no reachable CVEs.", required = false },
    { stage_id = "cce-cve-fix", description = "Open minimal bump PRs for reachable CVEs only.", required = false },
    { stage_id = "evidence-quality-gate", description = "LLM verifies that all three analysis stages produced sufficient evidence before recommending remediation.", required = true },
    { stage_id = "recommend", description = "Recommend remediation.", required = true },
  ]

  stage_bindings = [
    { stage_id = "integrity-check", agent_ref = sg_agent.supply_chain_analyst.name, runbook_refs = [sg_runbook_sop.npm_integrity_check.name], skill_refs = concat([sg_runbook_sop.npm_integrity_check.name], try(var.workflow_skill_refs["${local.workflow_name}::integrity-check"], [])) },
    { stage_id = "behavioral-sandbox", agent_ref = sg_agent.supply_chain_analyst.name, runbook_refs = [sg_runbook_sop.npm_behavioral_sandbox.name], skill_refs = concat([sg_runbook_sop.npm_behavioral_sandbox.name], try(var.workflow_skill_refs["${local.workflow_name}::behavioral-sandbox"], [])) },
    { stage_id = "manifest-anomaly", agent_ref = sg_agent.supply_chain_analyst.name, runbook_refs = [sg_runbook_sop.npm_manifest_anomaly.name], skill_refs = concat([sg_runbook_sop.npm_manifest_anomaly.name], try(var.workflow_skill_refs["${local.workflow_name}::manifest-anomaly"], [])) },
    { stage_id = "correlate", agent_ref = sg_agent.supply_chain_analyst.name, runbook_refs = [sg_runbook_sop.supply_chain_correlation.name], stage_depends_on = ["integrity-check", "behavioral-sandbox", "manifest-anomaly"], skill_refs = concat([sg_runbook_sop.supply_chain_correlation.name], try(var.workflow_skill_refs["${local.workflow_name}::correlate"], [])) },
    {
      stage_id         = "cce-cve-reachability"
      agent_ref        = sg_agent.supply_chain_analyst.name
      stage_depends_on = ["correlate"]
      runbook_refs = compact(concat(
        local.cce_reachability_stages_enabled ? [sg_runbook_sop.cce_cve_reachability[0].name] : [],
      ))
      skill_refs = concat(
        local.cce_reachability_stages_enabled ? [local.sop_cce_cve_reachability] : [],
        try(var.workflow_skill_refs["${local.workflow_name}::cce-cve-reachability"], []),
      )
      note = local.cce_reachability_stages_enabled ? "Ubuntu CCE reachability; note reachable_cve_count + IDs only (no full cce-cve.json)." : "CCE reachability disabled or Ubuntu not wired — skip."
    },
    {
      stage_id         = "cce-cve-skip-fix"
      action_type      = "conditional_skip"
      stage_depends_on = ["cce-cve-reachability"]
      action_config = {
        condition = "regex"
        match     = "reachable_cve_count=0"
        skip_to   = "evidence-quality-gate"
        reason    = "No reachable CVEs — skip fix PR LLM stage"
      }
    },
    {
      stage_id         = "cce-cve-fix"
      agent_ref        = sg_agent.supply_chain_analyst.name
      stage_depends_on = ["cce-cve-skip-fix"]
      runbook_refs = compact(concat(
        local.cce_reachability_stages_enabled ? [sg_runbook_sop.cce_cve_fix_pr[0].name] : [],
      ))
      skill_refs = try(var.workflow_skill_refs["${local.workflow_name}::cce-cve-fix"], [])
      note       = "Open fix PRs for reachable CVEs; comment on skipped unreachable alerts."
    },
    # evidence_gate: LLM verifies that the three analysis stages produced all required
    # evidence items (npm audit report, sandbox log, dependency graph delta) before
    # recommending remediation. Halts the workflow if evidence is insufficient.
    {
      stage_id         = "evidence-quality-gate"
      action_type      = "evidence_gate"
      stage_depends_on = ["cce-cve-fix"]
      action_config = {
        confirmation_items = jsonencode([
          "npm audit or provenance report is linked or summarized",
          "Sandbox run log or behavioral summary is documented",
          "Dependency graph delta (declared vs actual imports) is captured",
        ])
      }
    },
    { stage_id = "recommend", agent_ref = sg_agent.supply_chain_analyst.name, runbook_refs = [sg_runbook_sop.supply_chain_remediation_guidance.name], stage_depends_on = ["evidence-quality-gate"], skill_refs = concat([sg_runbook_sop.supply_chain_remediation_guidance.name], try(var.workflow_skill_refs["${local.workflow_name}::recommend"], [])) },
  ]
}
