terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "azure-saas-sre"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_alert_ingest_name = "saas-alert-ingest${local.suffix}"
  agent_investigator_name = "saas-investigator${local.suffix}"
  agent_remediator_name   = "saas-remediator${local.suffix}"

  workflow_incident_name = "pagerduty-saas-incident-response${local.suffix}"
  webhook_name           = "pagerduty-saas-alerts${local.suffix}"

  sop_normalize_name   = "saas-alert-normalization${local.suffix}"
  sop_investigate_name = "saas-auto-investigation${local.suffix}"
  sop_confluence_name  = "saas-confluence-runbook-match${local.suffix}"
  sop_remediate_name   = "saas-azure-automation-remediation${local.suffix}"

  remediation_pattern_name = "azure-automation-runbook${local.suffix}"

  datadog_integration_name    = "${local.module_prefix}-datadog${local.suffix}"
  pagerduty_integration_name  = "${local.module_prefix}-pagerduty${local.suffix}"
  confluence_integration_name = "${local.module_prefix}-confluence${local.suffix}"
  azure_integration_name      = "${local.module_prefix}-azure${local.suffix}"

  provision_datadog = (
    (trimspace(var.datadog_api_key) != "" || trimspace(var.datadog_secret_id) != "")
    && trimspace(var.existing_datadog_integration_name) == ""
  )
  provision_pagerduty = (
    (trimspace(var.pagerduty_api_token) != "" || trimspace(var.pagerduty_secret_id) != "")
    && trimspace(var.existing_pagerduty_integration_name) == ""
  )
  provision_confluence = (
    (
      (trimspace(var.confluence_api_token) != "" && trimspace(var.confluence_base_url) != "")
      || trimspace(var.confluence_secret_id) != ""
    )
    && trimspace(var.existing_confluence_integration_name) == ""
  )
  provision_azure = trimspace(var.existing_azure_integration_name) == ""

  resolved_datadog_integration_name = trimspace(var.existing_datadog_integration_name) != "" ? var.existing_datadog_integration_name : (
    local.provision_datadog ? module.datadog_integration[0].integration_name : ""
  )
  resolved_pagerduty_integration_name = trimspace(var.existing_pagerduty_integration_name) != "" ? var.existing_pagerduty_integration_name : (
    local.provision_pagerduty ? module.pagerduty_integration[0].integration_name : ""
  )
  resolved_confluence_integration_name = trimspace(var.existing_confluence_integration_name) != "" ? var.existing_confluence_integration_name : (
    local.provision_confluence ? module.confluence_integration[0].integration_name : ""
  )
  resolved_azure_integration_name = trimspace(var.existing_azure_integration_name) != "" ? var.existing_azure_integration_name : (
    local.provision_azure ? module.azure_integration[0].integration_name : ""
  )

  priorities_rego_literals       = join(", ", [for p in var.alert_ingest_allowed_priorities : format("%q", lower(p))])
  services_rego_literals         = join(", ", [for s in var.alert_ingest_allowed_services : format("%q", lower(s))])
  blocked_services_rego_literals = join(", ", [for s in var.alert_ingest_blocked_services : format("%q", lower(s))])
  environments_rego_literals     = join(", ", [for e in var.alert_ingest_allowed_environments : format("%q", lower(e))])

  alert_ingest_filter_rego = trimspace(templatefile("${path.module}/templates/alert-ingest-filter.rego.tftpl", {
    priorities_gate_enabled        = length(var.alert_ingest_allowed_priorities) > 0
    priorities_rego_literals       = local.priorities_rego_literals
    services_gate_enabled          = length(var.alert_ingest_allowed_services) > 0
    services_rego_literals         = local.services_rego_literals
    blocked_gate_enabled           = length(var.alert_ingest_blocked_services) > 0
    blocked_services_rego_literals = local.blocked_services_rego_literals
    environments_gate_enabled      = length(var.alert_ingest_allowed_environments) > 0
    environments_rego_literals     = local.environments_rego_literals
  }))

  confluence_runbook_template_vars = {
    confluence_space_key = var.confluence_space_key
  }

  azure_automation_template_vars = {
    azure_automation_account_name       = var.azure_automation_account_name
    azure_automation_resource_group     = var.azure_automation_resource_group
    azure_automation_subscription_id    = var.azure_automation_subscription_id
    azure_automation_runbook_name_hints = jsonencode(var.azure_automation_runbook_name_hints)
  }

  attach_policy = {
    sre_remediation = try(var.policy_create_flags.sre_remediation, true)
    prod_write_gate = try(var.policy_create_flags.prod_write_gate, true)
  }
}

# =============================================================================
# Integration submodules
# =============================================================================

module "datadog_integration" {
  count  = local.provision_datadog ? 1 : 0
  source = "../aios-integration-datadog"

  integration_name   = local.datadog_integration_name
  datadog_api_key    = var.datadog_api_key
  datadog_app_key    = var.datadog_app_key
  datadog_site       = var.datadog_site
  existing_secret_id = var.datadog_secret_id
  description        = "Datadog integration owned by ${local.agent_investigator_name} (SaaS incident investigation)."
}

module "pagerduty_integration" {
  count  = local.provision_pagerduty ? 1 : 0
  source = "../aios-integration-pagerduty"

  integration_name   = local.pagerduty_integration_name
  api_token          = var.pagerduty_api_token
  existing_secret_id = var.pagerduty_secret_id
  description        = "PagerDuty integration owned by ${local.agent_alert_ingest_name} (SaaS alert ingest)."
}

module "confluence_integration" {
  count  = local.provision_confluence ? 1 : 0
  source = "../aios-integration-confluence"

  integration_name   = local.confluence_integration_name
  base_url           = var.confluence_base_url
  email              = var.confluence_email
  api_token          = var.confluence_api_token
  existing_secret_id = var.confluence_secret_id
  description        = "Confluence integration owned by ${local.agent_remediator_name} (operational runbooks)."
}

module "azure_integration" {
  count  = local.provision_azure ? 1 : 0
  source = "../aios-integration-azure"

  integration_name   = local.azure_integration_name
  existing_secret_id = var.azure_secret_id
  description        = "Azure integration owned by ${local.agent_remediator_name} (Automation runbook remediation)."
}

resource "terraform_data" "azure_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_azure_integration_name) != ""
      error_message = "aios-agent-azure-saas-sre needs an Azure Guild integration: provide `azure_secret_id` (the module provisions one) or `existing_azure_integration_name`."
    }
  }
}

# =============================================================================
# Agents
# =============================================================================

resource "sg_agent" "saas_alert_ingest" {
  name        = local.agent_alert_ingest_name
  persona     = file("${path.module}/personas/saas-alert-ingest.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_pagerduty_integration_name,
    local.resolved_datadog_integration_name,
  ])
}

resource "sg_agent" "saas_investigator" {
  name        = local.agent_investigator_name
  persona     = file("${path.module}/personas/saas-investigator.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_datadog_integration_name,
    local.resolved_azure_integration_name,
    local.resolved_confluence_integration_name,
  ])
}

resource "sg_agent" "saas_remediator" {
  name        = local.agent_remediator_name
  persona     = file("${path.module}/personas/saas-remediator.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = compact([
      local.resolved_azure_integration_name != "" ? "${local.resolved_azure_integration_name}_test_connection" : "",
    ])
  }

  integrations = compact([
    local.resolved_azure_integration_name,
    local.resolved_confluence_integration_name,
    local.resolved_pagerduty_integration_name,
    local.resolved_datadog_integration_name,
  ])
}

# =============================================================================
# Agent budgets
# =============================================================================

resource "sg_agent_budget" "saas_alert_ingest" {
  agent_name  = sg_agent.saas_alert_ingest.name
  limit_usd   = var.agent_budgets.alert_ingest
  period_type = "daily"
}

resource "sg_agent_budget" "saas_investigator" {
  agent_name  = sg_agent.saas_investigator.name
  limit_usd   = var.agent_budgets.investigator
  period_type = "daily"
}

resource "sg_agent_budget" "saas_remediator" {
  agent_name  = sg_agent.saas_remediator.name
  limit_usd   = var.agent_budgets.remediator
  period_type = "daily"
}

# =============================================================================
# Policy attachments
# =============================================================================

resource "sg_agent_policy_attachment" "saas_alert_ingest_dangerous_ops" {
  agent_name = sg_agent.saas_alert_ingest.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "saas_investigator_dangerous_ops" {
  agent_name = sg_agent.saas_investigator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "saas_remediator_dangerous_ops" {
  agent_name = sg_agent.saas_remediator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "saas_remediator_sre_remediation" {
  count      = local.attach_policy.sre_remediation ? 1 : 0
  agent_name = sg_agent.saas_remediator.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "saas_remediator_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate ? 1 : 0
  agent_name = sg_agent.saas_remediator.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

# =============================================================================
# Runbooks and remediation pattern
# =============================================================================

resource "sg_runbook_sop" "alert_normalization" {
  name        = local.sop_normalize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-alert-normalization.md", {}))
}

resource "sg_runbook_sop" "auto_investigation" {
  name        = local.sop_investigate_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-auto-investigation.md", {}))
}

resource "sg_runbook_sop" "confluence_runbook_match" {
  name        = local.sop_confluence_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-confluence-runbook-match.md", local.confluence_runbook_template_vars))
}

resource "sg_runbook_sop" "azure_automation_remediation" {
  name    = local.sop_remediate_name
  approve = true
  description = trimspace(templatefile("${path.module}/templates/runbook-azure-automation-remediation.md", merge(local.azure_automation_template_vars, {
    confluence_space_key = var.confluence_space_key
  })))
}

resource "sg_remediation_pattern" "azure_automation_runbook" {
  name              = local.remediation_pattern_name
  description       = trimspace(templatefile("${path.module}/templates/remediation-azure-automation-runbook.md", {}))
  risk_level        = "medium"
  blast_radius      = "single-tenant"
  requires_approval = true
  approve           = true
}

# =============================================================================
# Workflow — PagerDuty SaaS incident response
# =============================================================================

resource "sg_workflow" "pagerduty_saas_incident_response" {
  name        = local.workflow_incident_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-pagerduty-saas-incident-response.md", local.azure_automation_template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "40"
  }

  triggers = [
    { field = "source", values = ["pagerduty"], type = "active", source = "pagerduty" },
    { field = "incident_title_contains", values = ["azure", "saas", "tenant"], type = "passive" },
  ]

  required_inputs = ["incident_id"]
  optional_inputs = ["service_name", "environment", "tenant_id"]

  runbook_refs = [
    sg_runbook_sop.alert_normalization.name,
    sg_runbook_sop.auto_investigation.name,
    sg_runbook_sop.confluence_runbook_match.name,
    sg_runbook_sop.azure_automation_remediation.name,
  ]

  example_queries = [
    "PagerDuty P2 fired for tenant acme-prod — investigate Azure SaaS checkout latency",
    "Auto-remediate storage queue backlog for single-tenant ingestion failure",
    "Match Confluence runbook and restart App Service for SaaS API timeout",
  ]

  stages = [
    { stage_id = "alert-ingest-filter", description = "Deterministic Rego filter on raw PagerDuty webhook payload (priority, service, environment allowlists; blocked services).", required = true },
    { stage_id = "normalize-alert", description = "Parse PagerDuty event and emit normalized_alert JSON for downstream stages.", required = true },
    { stage_id = "auto-investigate", description = "Query Datadog and Azure for root-cause evidence on the affected tenant workload.", required = true },
    { stage_id = "match-confluence-runbook", description = "Search Confluence for the operational runbook and extract Azure Automation metadata.", required = true },
    { stage_id = "remediation-safety-gate", description = "Inline Rego blocks auto-remediation when investigation output reflects P1/SEV1-class severity.", required = true },
    { stage_id = "execute-azure-remediation", description = "Start the matched Azure Automation runbook and verify post-action health.", required = true },
  ]

  stage_bindings = [
    {
      stage_id    = "alert-ingest-filter"
      action_type = "policy_check"
      action_config = {
        inline_rego = local.alert_ingest_filter_rego
      }
    },
    {
      stage_id         = "normalize-alert"
      agent_ref        = sg_agent.saas_alert_ingest.name
      stage_depends_on = ["alert-ingest-filter"]
      runbook_refs     = [sg_runbook_sop.alert_normalization.name]
      skill_refs       = concat(["saas-pagerduty-alert-normalize"], try(var.workflow_skill_refs["pagerduty-saas-incident-response::normalize-alert"], []))
      note             = "Normalize inbound PagerDuty payload into stable incident envelope."
    },
    {
      stage_id         = "auto-investigate"
      agent_ref        = sg_agent.saas_investigator.name
      stage_depends_on = ["normalize-alert"]
      runbook_refs     = [sg_runbook_sop.auto_investigation.name]
      skill_refs       = concat(["saas-datadog-azure-investigation"], try(var.workflow_skill_refs["pagerduty-saas-incident-response::auto-investigate"], []))
      note             = "Cross-cloud investigation using Datadog + Azure integrations."
    },
    {
      stage_id         = "match-confluence-runbook"
      agent_ref        = sg_agent.saas_investigator.name
      stage_depends_on = ["auto-investigate"]
      runbook_refs     = [sg_runbook_sop.confluence_runbook_match.name]
      skill_refs       = concat(["saas-confluence-runbook-match"], try(var.workflow_skill_refs["pagerduty-saas-incident-response::match-confluence-runbook"], []))
      note             = "Locate Confluence runbook and extract Automation runbook metadata."
    },
    {
      stage_id         = "remediation-safety-gate"
      action_type      = "policy_check"
      stage_depends_on = ["match-confluence-runbook"]
      action_config = {
        inline_rego = <<-REGO
          package stage_gate

          import rego.v1

          default allow = true

          # Block auto-remediation for P1/SEV1. Match word-boundary severity tokens (avoid p10, sev10, etc.).
          allow = false if { is_critical_severity }

          _text := lower(input.stage_input)

          is_critical_severity if { regex.match(`\bp1\b`, _text) }
          is_critical_severity if { regex.match(`\bsev[- ]?1\b`, _text) }
          is_critical_severity if { contains(_text, "severity: 1") }

          deny contains "P1/SEV1 incident requires human-in-the-loop approval for Azure Automation remediation" if {
              is_critical_severity
          }
        REGO
      }
    },
    {
      stage_id         = "execute-azure-remediation"
      agent_ref        = sg_agent.saas_remediator.name
      stage_depends_on = ["remediation-safety-gate"]
      runbook_refs     = [sg_runbook_sop.azure_automation_remediation.name]
      skill_refs       = concat([sg_remediation_pattern.azure_automation_runbook.name], try(var.workflow_skill_refs["pagerduty-saas-incident-response::execute-azure-remediation"], []))
      note             = "Execute Azure Automation runbook with HITL gates and post-action verification."
    },
  ]
}

# =============================================================================
# PagerDuty webhook ingress
# =============================================================================

resource "sg_webhook" "pagerduty_saas_alerts" {
  count = var.enable_pagerduty_webhook ? 1 : 0

  name          = local.webhook_name
  target_type   = "workflow"
  target_name   = sg_workflow.pagerduty_saas_incident_response.name
  action        = "A PagerDuty alert fired for the Azure SaaS tenant. Parse the webhook JSON, apply ingest filters, investigate with Datadog and Azure, match the Confluence runbook, and remediate via Azure Automation when safe."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
