terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.21, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "privatesaas-sre"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_incident_ingest_name     = "incident-ingest${local.suffix}"
  agent_investigator_name        = "privatesaas-sre-investigator${local.suffix}"
  agent_runbook_coordinator_name = "runbook-coordinator${local.suffix}"

  workflow_incident_name   = "privatesaas-incident-response${local.suffix}"
  workflow_audit_name      = "privatesaas-runbook-audit${local.suffix}"
  webhook_grafana_name     = "grafana-privatesaas-sre${local.suffix}"
  webhook_firehydrant_name = "firehydrant-privatesaas-sre${local.suffix}"

  sop_generic_triage_name  = "privatesaas-sre-generic-triage${local.suffix}"
  sop_generic_gcp_name     = "privatesaas-sre-generic-gcp${local.suffix}"
  sop_generic_runbook_name = "privatesaas-sre-generic-runbook-routing${local.suffix}"
  sop_normalize_name       = "privatesaas-sre-normalize-incident${local.suffix}"
  sop_grafana_name         = "privatesaas-sre-grafana-signals${local.suffix}"
  sop_gcp_name             = "privatesaas-sre-investigate-gcp${local.suffix}"
  sop_firehydrant_name     = "privatesaas-sre-enrich-firehydrant${local.suffix}"
  sop_internal_name        = "privatesaas-sre-query-internal-tooling${local.suffix}"
  sop_match_runbooks_name  = "privatesaas-sre-match-runbooks${local.suffix}"
  sop_synthesize_name      = "privatesaas-sre-synthesize-rca${local.suffix}"
  sop_recommend_name       = "privatesaas-sre-recommend-actions${local.suffix}"
  sop_inventory_name       = "privatesaas-sre-inventory-runbooks${local.suffix}"
  sop_coverage_name        = "privatesaas-sre-coverage-gaps${local.suffix}"

  evidence_name = "privatesaas-sre${local.suffix}"

  grafana_integration_name       = "${local.module_prefix}-grafana${local.suffix}"
  gcp_integration_name           = "${local.module_prefix}-gcp${local.suffix}"
  firehydrant_integration_name   = "${local.module_prefix}-firehydrant${local.suffix}"
  internal_tool_integration_name = "${local.module_prefix}-internal-tool${local.suffix}"

  resolved_model_names = length(compact(var.bifrost_model_names)) > 0 ? compact(var.bifrost_model_names) : compact(var.model_names)

  provision_grafana = (
    (trimspace(var.grafana_token) != "" || trimspace(var.grafana_secret_id) != "")
    && trimspace(var.existing_grafana_integration_name) == ""
  )
  provision_gcp = (
    (
      trimspace(var.gcp_secret_id) != ""
      || (trimspace(var.gcp_credentials_json) != "" && trimspace(var.gcp_project_id) != "")
    )
    && trimspace(var.existing_gcp_integration_name) == ""
  )
  provision_firehydrant = (
    (trimspace(var.firehydrant_api_key) != "" || trimspace(var.firehydrant_secret_id) != "")
    && trimspace(var.existing_firehydrant_integration_name) == ""
  )
  provision_internal_tool = (
    (
      trimspace(var.internal_tool_base_url) != ""
      || trimspace(var.internal_tool_secret_id) != ""
    )
    && trimspace(var.existing_internal_tool_integration_name) == ""
  )

  resolved_grafana_integration_name = trimspace(var.existing_grafana_integration_name) != "" ? var.existing_grafana_integration_name : (
    local.provision_grafana ? module.grafana_integration[0].integration_name : ""
  )
  resolved_gcp_integration_name = trimspace(var.existing_gcp_integration_name) != "" ? var.existing_gcp_integration_name : (
    local.provision_gcp ? module.gcp_integration[0].integration_name : ""
  )
  resolved_firehydrant_integration_name = trimspace(var.existing_firehydrant_integration_name) != "" ? var.existing_firehydrant_integration_name : (
    local.provision_firehydrant ? module.firehydrant_integration[0].integration_name : ""
  )
  resolved_internal_tool_integration_name = trimspace(var.existing_internal_tool_integration_name) != "" ? var.existing_internal_tool_integration_name : (
    local.provision_internal_tool ? module.internal_tool_integration[0].integration_name : ""
  )

  severities_rego_literals       = join(", ", [for s in var.incident_ingest_allowed_severities : format("%q", lower(s))])
  services_rego_literals         = join(", ", [for s in var.incident_ingest_allowed_services : format("%q", lower(s))])
  environments_rego_literals     = join(", ", [for e in var.incident_ingest_allowed_environments : format("%q", lower(e))])
  blocked_services_rego_literals = join(", ", [for b in var.incident_ingest_blocked_services : format("%q", lower(b))])

  incident_ingest_filter_rego = trimspace(templatefile("${path.module}/templates/incident-ingest-filter.rego.tftpl", {
    severities_gate_enabled        = length(var.incident_ingest_allowed_severities) > 0
    severities_rego_literals       = local.severities_rego_literals
    services_gate_enabled          = length(var.incident_ingest_allowed_services) > 0
    services_rego_literals         = local.services_rego_literals
    environments_gate_enabled      = length(var.incident_ingest_allowed_environments) > 0
    environments_rego_literals     = local.environments_rego_literals
    blocked_gate_enabled           = length(var.incident_ingest_blocked_services) > 0
    blocked_services_rego_literals = local.blocked_services_rego_literals
  }))

  external_runbook_catalog_markdown = length(var.external_runbook_catalog) > 0 ? join("\n", [
    for name, entry in var.external_runbook_catalog : "- **${name}**: ${entry.description} — ${entry.url}"
  ]) : "_No external catalog entries configured._"

  module_runbook_catalog = <<-EOT
- `${local.sop_generic_triage_name}`: Generic PrivateSaaS incident triage
- `${local.sop_generic_gcp_name}`: Generic GCP investigation
- `${local.sop_generic_runbook_name}`: Multi-source runbook routing
EOT

  bifrost_gateway_comment = trimspace(var.bifrost_gateway_url) != "" ? " via ${trimspace(var.bifrost_gateway_url)}" : ""

  investigation_template_vars = {
    private_saas_environment_label    = var.private_saas_environment_label
    gcp_project_id                    = var.gcp_project_id
    gcp_region                        = var.gcp_region
    external_runbook_catalog_markdown = local.external_runbook_catalog_markdown
    module_runbook_catalog            = local.module_runbook_catalog
    bifrost_gateway_comment           = local.bifrost_gateway_comment
  }

  attach_policy = {
    sre_remediation = try(var.policy_create_flags.sre_remediation, true)
    prod_write_gate = try(var.policy_create_flags.prod_write_gate, true)
  }
}

# =============================================================================
# Integration submodules
# =============================================================================

module "grafana_integration" {
  count  = local.provision_grafana ? 1 : 0
  source = "../aios-integration-grafana"

  integration_name   = local.grafana_integration_name
  grafana_server     = var.grafana_server
  grafana_token      = var.grafana_token
  existing_secret_id = var.grafana_secret_id
  description        = "Grafana integration owned by ${local.agent_investigator_name} (PrivateSaaS SRE)."
}

module "gcp_integration" {
  count  = local.provision_gcp ? 1 : 0
  source = "../aios-integration-gcp"

  integration_name     = local.gcp_integration_name
  gcp_credentials_json = var.gcp_credentials_json
  gcp_project_id       = var.gcp_project_id
  gcp_region           = var.gcp_region
  existing_secret_id   = var.gcp_secret_id
}

module "firehydrant_integration" {
  count  = local.provision_firehydrant ? 1 : 0
  source = "../aios-integration-firehydrant"

  integration_name   = local.firehydrant_integration_name
  api_key            = var.firehydrant_api_key
  base_url           = var.firehydrant_base_url
  existing_secret_id = var.firehydrant_secret_id
  description        = "FireHydrant integration owned by ${local.agent_incident_ingest_name} (PrivateSaaS SRE)."
}

module "internal_tool_integration" {
  count  = local.provision_internal_tool ? 1 : 0
  source = "../aios-integration-internal-tool"

  integration_name   = local.internal_tool_integration_name
  base_url           = var.internal_tool_base_url
  api_key            = var.internal_tool_api_key
  existing_secret_id = var.internal_tool_secret_id
  description        = "Internal tooling REST API owned by ${local.agent_investigator_name} (PrivateSaaS SRE)."
}

resource "terraform_data" "grafana_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_grafana_integration_name) != ""
      error_message = "aios-agent-privatesaas-sre needs a Grafana Guild integration: provide `grafana_token`/`grafana_secret_id`, or `existing_grafana_integration_name`."
    }
  }
}

resource "terraform_data" "gcp_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_gcp_integration_name) != ""
      error_message = "aios-agent-privatesaas-sre needs a GCP Guild integration: provide `gcp_secret_id`, inline credentials + `gcp_project_id`, or `existing_gcp_integration_name`."
    }
  }
}

resource "terraform_data" "firehydrant_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_firehydrant_integration_name) != ""
      error_message = "aios-agent-privatesaas-sre needs a FireHydrant Guild integration: provide `firehydrant_api_key`/`firehydrant_secret_id`, or `existing_firehydrant_integration_name`."
    }
  }
}

resource "terraform_data" "internal_tool_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_internal_tool_integration_name) != ""
      error_message = "aios-agent-privatesaas-sre needs an internal tooling Guild integration: provide `internal_tool_base_url`/`internal_tool_secret_id`, or `existing_internal_tool_integration_name`."
    }
  }
}

# =============================================================================
# Agents
# =============================================================================

resource "sg_agent" "incident_ingest" {
  name        = local.agent_incident_ingest_name
  persona     = file("${path.module}/personas/incident-ingest.md")
  model_names = local.resolved_model_names

  integrations = compact([
    local.resolved_grafana_integration_name,
    local.resolved_firehydrant_integration_name,
  ])
}

resource "sg_agent" "privatesaas_sre_investigator" {
  name        = local.agent_investigator_name
  persona     = file("${path.module}/personas/privatesaas-sre-investigator.md")
  model_names = local.resolved_model_names

  integrations = compact([
    local.resolved_grafana_integration_name,
    local.resolved_gcp_integration_name,
    local.resolved_firehydrant_integration_name,
    local.resolved_internal_tool_integration_name,
  ])
}

resource "sg_agent" "runbook_coordinator" {
  name        = local.agent_runbook_coordinator_name
  persona     = file("${path.module}/personas/runbook-coordinator.md")
  model_names = local.resolved_model_names

  integrations = compact([
    local.resolved_grafana_integration_name,
    local.resolved_firehydrant_integration_name,
    local.resolved_internal_tool_integration_name,
  ])
}

# =============================================================================
# Agent budgets
# =============================================================================

resource "sg_agent_budget" "incident_ingest" {
  agent_name  = sg_agent.incident_ingest.name
  limit_usd   = var.agent_budgets.incident_ingest
  period_type = "daily"
}

resource "sg_agent_budget" "privatesaas_sre_investigator" {
  agent_name  = sg_agent.privatesaas_sre_investigator.name
  limit_usd   = var.agent_budgets.investigator
  period_type = "daily"
}

resource "sg_agent_budget" "runbook_coordinator" {
  agent_name  = sg_agent.runbook_coordinator.name
  limit_usd   = var.agent_budgets.runbook_coordinator
  period_type = "daily"
}

# =============================================================================
# Policy attachments
# =============================================================================

resource "sg_agent_policy_attachment" "incident_ingest_dangerous_ops" {
  agent_name = sg_agent.incident_ingest.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "investigator_dangerous_ops" {
  agent_name = sg_agent.privatesaas_sre_investigator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "runbook_coordinator_dangerous_ops" {
  agent_name = sg_agent.runbook_coordinator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "investigator_sre_remediation" {
  count      = local.attach_policy.sre_remediation ? 1 : 0
  agent_name = sg_agent.privatesaas_sre_investigator.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "investigator_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate ? 1 : 0
  agent_name = sg_agent.privatesaas_sre_investigator.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

# =============================================================================
# Runbooks — generic (module library)
# =============================================================================

resource "sg_runbook_sop" "generic_triage" {
  name        = local.sop_generic_triage_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-generic-incident-triage.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "generic_gcp" {
  name        = local.sop_generic_gcp_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-generic-gcp-investigation.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "generic_runbook_routing" {
  name        = local.sop_generic_runbook_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-generic-runbook-routing.md", local.investigation_template_vars))
}

# =============================================================================
# Runbooks — workflow stages
# =============================================================================

resource "sg_runbook_sop" "normalize_incident" {
  name        = local.sop_normalize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-normalize-incident.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "grafana_signals" {
  name        = local.sop_grafana_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-grafana-signals.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "investigate_gcp" {
  name        = local.sop_gcp_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-investigate-gcp.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "enrich_firehydrant" {
  name        = local.sop_firehydrant_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-enrich-firehydrant.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "query_internal_tooling" {
  name        = local.sop_internal_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-query-internal-tooling.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "match_runbooks" {
  name        = local.sop_match_runbooks_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-match-runbooks.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "synthesize_rca" {
  name        = local.sop_synthesize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-synthesize-rca.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "recommend_actions" {
  name        = local.sop_recommend_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-recommend-actions.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "inventory_runbooks" {
  name        = local.sop_inventory_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-inventory-runbooks.md", local.investigation_template_vars))
}

resource "sg_runbook_sop" "coverage_gaps" {
  name        = local.sop_coverage_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-coverage-gaps.md", local.investigation_template_vars))
}

# =============================================================================
# Evidence checklist (optional)
# =============================================================================

resource "sg_evidence_checklist" "privatesaas_sre" {
  count       = var.enable_evidence_checklist ? 1 : 0
  name        = local.evidence_name
  description = "Proof-of-work for PrivateSaaS SRE incident response before recommending production actions."
  approve     = true
  required_items = [
    "incident_normalized",
    "grafana_signals_collected",
    "gcp_signals_collected",
    "runbooks_matched",
    "rca_documented",
  ]
  scoring = {
    min_required         = 4
    confidence_threshold = 0.70
  }
  metadata = { playbook = "privatesaas-incident-response" }
}

# =============================================================================
# Workflow — PrivateSaaS incident response
# =============================================================================

resource "sg_workflow" "privatesaas_incident_response" {
  name        = local.workflow_incident_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-privatesaas-incident-response.md", local.investigation_template_vars))
  approve     = true

  evidence_checklist_ref = var.enable_evidence_checklist ? sg_evidence_checklist.privatesaas_sre[0].name : null

  metadata = {
    planner_max_tool_iterations = "45"
  }

  triggers = [
    { field = "source", values = ["grafana", "firehydrant"], type = "active" },
    { field = "incident_title_contains", values = ["privatesaas", "incident", "outage", "sev"], type = "passive" },
  ]

  required_inputs = ["incident_title"]
  optional_inputs = ["environment", "service", "severity", "firehydrant_incident_id"]

  runbook_refs = [
    sg_runbook_sop.generic_triage.name,
    sg_runbook_sop.generic_gcp.name,
    sg_runbook_sop.generic_runbook_routing.name,
    sg_runbook_sop.normalize_incident.name,
    sg_runbook_sop.grafana_signals.name,
    sg_runbook_sop.investigate_gcp.name,
    sg_runbook_sop.enrich_firehydrant.name,
    sg_runbook_sop.query_internal_tooling.name,
    sg_runbook_sop.match_runbooks.name,
    sg_runbook_sop.synthesize_rca.name,
    sg_runbook_sop.recommend_actions.name,
  ]

  example_queries = [
    "FireHydrant P2 on checkout-api in prod — correlate Grafana and GCP logs, match runbooks, synthesize RCA",
    "Grafana critical alert in PrivateSaaS VPC — enrich FireHydrant incident and internal service catalog",
    "Recommend document-only remediation steps for production database latency incident",
  ]

  stages = [
    { stage_id = "incident-ingest-filter", description = "Deterministic Rego filter on raw incident payload (severity, service, environment allowlists; blocked services).", required = true },
    { stage_id = "normalize-incident", description = "Parse FireHydrant/Grafana payloads and emit normalized_incident JSON.", required = true },
    { stage_id = "collect-grafana-signals", description = "Query private Grafana dashboards and metrics for the incident window.", required = true },
    { stage_id = "investigate-gcp", description = "Cloud Logging, Monitoring, and GKE signals (read-only).", required = true },
    { stage_id = "enrich-firehydrant", description = "FireHydrant timeline, responders, and linked alerts.", required = true },
    { stage_id = "query-internal-tooling", description = "Service ownership, dependencies, and catalog context via internal REST API.", required = true },
    { stage_id = "match-runbooks", description = "Multi-source runbook matching (module SOPs, FireHydrant, internal tool, external catalog).", required = true },
    { stage_id = "synthesize-rca", description = "Structured RCA with timeline, root cause, and evidence links.", required = true },
    { stage_id = "remediation-safety-gate", description = "Inline Rego blocks P1/SEV1 auto-remediation recommendations.", required = true },
    { stage_id = "recommend-actions", description = "Document-only remediation recommendations for production.", required = true },
  ]

  stage_bindings = [
    {
      stage_id    = "incident-ingest-filter"
      action_type = "policy_check"
      action_config = {
        inline_rego = local.incident_ingest_filter_rego
      }
    },
    {
      stage_id         = "normalize-incident"
      agent_ref        = sg_agent.incident_ingest.name
      stage_depends_on = ["incident-ingest-filter"]
      runbook_refs     = [sg_runbook_sop.normalize_incident.name, sg_runbook_sop.generic_triage.name]
      skill_refs       = concat(["privatesaas-sre-normalize-incident"], try(var.workflow_skill_refs["privatesaas-incident-response::normalize-incident"], []))
      note             = "Normalize FireHydrant and Grafana signals into normalized_incident JSON."
    },
    {
      stage_id         = "collect-grafana-signals"
      agent_ref        = sg_agent.privatesaas_sre_investigator.name
      stage_depends_on = ["normalize-incident"]
      runbook_refs     = [sg_runbook_sop.grafana_signals.name]
      skill_refs       = concat(["privatesaas-sre-grafana-signals"], try(var.workflow_skill_refs["privatesaas-incident-response::collect-grafana-signals"], []))
      note             = "Collect private Grafana observability signals."
    },
    {
      stage_id         = "investigate-gcp"
      agent_ref        = sg_agent.privatesaas_sre_investigator.name
      stage_depends_on = ["collect-grafana-signals"]
      runbook_refs     = [sg_runbook_sop.investigate_gcp.name, sg_runbook_sop.generic_gcp.name]
      skill_refs       = concat(["privatesaas-sre-investigate-gcp"], try(var.workflow_skill_refs["privatesaas-incident-response::investigate-gcp"], []))
      note             = "GCP logging, metrics, and GKE investigation."
    },
    {
      stage_id         = "enrich-firehydrant"
      agent_ref        = sg_agent.privatesaas_sre_investigator.name
      stage_depends_on = ["investigate-gcp"]
      runbook_refs     = [sg_runbook_sop.enrich_firehydrant.name]
      skill_refs       = concat(["privatesaas-sre-enrich-firehydrant"], try(var.workflow_skill_refs["privatesaas-incident-response::enrich-firehydrant"], []))
      note             = "Enrich incident from FireHydrant timeline and responders."
    },
    {
      stage_id         = "query-internal-tooling"
      agent_ref        = sg_agent.privatesaas_sre_investigator.name
      stage_depends_on = ["enrich-firehydrant"]
      runbook_refs     = [sg_runbook_sop.query_internal_tooling.name]
      skill_refs       = concat(["privatesaas-sre-query-internal-tooling"], try(var.workflow_skill_refs["privatesaas-incident-response::query-internal-tooling"], []))
      note             = "Query internal operator console / service catalog."
    },
    {
      stage_id         = "match-runbooks"
      agent_ref        = sg_agent.runbook_coordinator.name
      stage_depends_on = ["query-internal-tooling"]
      runbook_refs     = [sg_runbook_sop.match_runbooks.name, sg_runbook_sop.generic_runbook_routing.name]
      skill_refs       = concat(["privatesaas-sre-match-runbooks"], try(var.workflow_skill_refs["privatesaas-incident-response::match-runbooks"], []))
      note             = "Match runbooks from module SOPs, FireHydrant, internal tool, and external catalog."
    },
    {
      stage_id         = "synthesize-rca"
      agent_ref        = sg_agent.privatesaas_sre_investigator.name
      stage_depends_on = ["match-runbooks"]
      runbook_refs     = [sg_runbook_sop.synthesize_rca.name]
      skill_refs       = concat(["privatesaas-sre-synthesize-rca"], try(var.workflow_skill_refs["privatesaas-incident-response::synthesize-rca"], []))
      note             = "Synthesize structured RCA JSON."
    },
    {
      stage_id         = "remediation-safety-gate"
      action_type      = "policy_check"
      stage_depends_on = ["synthesize-rca"]
      action_config = {
        inline_rego = <<-REGO
          package stage_gate

          import rego.v1

          default allow = true

          allow = false if { is_critical_severity }

          _text := lower(input.stage_input)

          is_critical_severity if { regex.match(`\bp1\b`, _text) }
          is_critical_severity if { regex.match(`\bsev[- ]?1\b`, _text) }
          is_critical_severity if { contains(_text, "severity: 1") }
          is_critical_severity if { regex.match(`\bcritical\b`, _text) }

          deny contains "P1/SEV1 incident requires human-in-the-loop approval before remediation recommendations" if {
              is_critical_severity
          }
        REGO
      }
    },
    {
      stage_id         = "recommend-actions"
      agent_ref        = sg_agent.privatesaas_sre_investigator.name
      stage_depends_on = ["remediation-safety-gate"]
      runbook_refs     = [sg_runbook_sop.recommend_actions.name]
      skill_refs       = concat(["privatesaas-sre-recommend-actions"], try(var.workflow_skill_refs["privatesaas-incident-response::recommend-actions"], []))
      note             = "Document-only remediation recommendations for production."
    },
  ]
}

# =============================================================================
# Workflow — PrivateSaaS runbook audit (read-only)
# =============================================================================

resource "sg_workflow" "privatesaas_runbook_audit" {
  name        = local.workflow_audit_name
  domain      = "devops"
  description = trimspace(templatefile("${path.module}/templates/workflow-privatesaas-runbook-audit.md", local.investigation_template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "25"
  }

  triggers = [
    { field = "incident_title_contains", values = ["runbook", "audit", "coverage", "sop"], type = "passive" },
  ]

  required_inputs = []
  optional_inputs = ["environment", "service"]

  runbook_refs = [
    sg_runbook_sop.inventory_runbooks.name,
    sg_runbook_sop.coverage_gaps.name,
    sg_runbook_sop.generic_runbook_routing.name,
  ]

  example_queries = [
    "Audit PrivateSaaS runbook coverage for payment services",
    "Inventory runbooks across FireHydrant, internal catalog, and module SOPs",
  ]

  stages = [
    { stage_id = "inventory-runbooks", description = "Read-only inventory of runbooks across all configured sources.", required = true },
    { stage_id = "coverage-gaps", description = "Report services and failure modes lacking adequate runbook coverage.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "inventory-runbooks"
      agent_ref    = sg_agent.runbook_coordinator.name
      runbook_refs = [sg_runbook_sop.inventory_runbooks.name]
      skill_refs   = concat(["privatesaas-sre-inventory-runbooks"], try(var.workflow_skill_refs["privatesaas-runbook-audit::inventory-runbooks"], []))
      note         = "Inventory runbooks from module SOPs, FireHydrant, internal tooling, and external catalog."
    },
    {
      stage_id         = "coverage-gaps"
      agent_ref        = sg_agent.runbook_coordinator.name
      stage_depends_on = ["inventory-runbooks"]
      runbook_refs     = [sg_runbook_sop.coverage_gaps.name]
      skill_refs       = concat(["privatesaas-sre-coverage-gaps"], try(var.workflow_skill_refs["privatesaas-runbook-audit::coverage-gaps"], []))
      note             = "Identify runbook coverage gaps."
    },
  ]
}

# =============================================================================
# Webhook ingress
# =============================================================================

resource "sg_webhook" "grafana_privatesaas_sre" {
  count = var.enable_grafana_webhook ? 1 : 0

  name          = local.webhook_grafana_name
  target_type   = "workflow"
  target_name   = sg_workflow.privatesaas_incident_response.name
  action        = "A private Grafana alert fired for PrivateSaaS. Parse the webhook JSON, apply ingest filters, investigate with Grafana/GCP/FireHydrant/internal tooling, match runbooks, synthesize RCA, and recommend document-only actions when allowed."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}

resource "sg_webhook" "firehydrant_privatesaas_sre" {
  count = var.enable_firehydrant_webhook ? 1 : 0

  name          = local.webhook_firehydrant_name
  target_type   = "workflow"
  target_name   = sg_workflow.privatesaas_incident_response.name
  action        = "A FireHydrant incident event fired for PrivateSaaS. Parse the webhook JSON, apply ingest filters, correlate Grafana signals, investigate GCP, enrich FireHydrant context, match multi-source runbooks, and synthesize RCA."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
