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
  module_prefix = "privatesaas-devops-sre"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_alert_ingest_name = "grafana-alert-ingest${local.suffix}"
  agent_investigator_name = "privatesaas-investigator${local.suffix}"
  agent_remediator_name   = "privatesaas-remediator${local.suffix}"

  workflow_incident_name = "privatesaas-incident-response${local.suffix}"
  workflow_audit_name    = "privatesaas-connectivity-audit${local.suffix}"
  webhook_name           = "grafana-privatesaas-alerts${local.suffix}"

  sop_normalize_name       = "privatesaas-alert-normalization${local.suffix}"
  sop_grafana_name         = "privatesaas-grafana-signals${local.suffix}"
  sop_aws_name             = "privatesaas-aws-correlation${local.suffix}"
  sop_firewall_path_name   = "privatesaas-firewall-path-analysis${local.suffix}"
  sop_synthesize_name      = "privatesaas-incident-synthesis${local.suffix}"
  sop_remediate_name       = "privatesaas-recommend-remediation${local.suffix}"
  sop_grafana_health_name  = "privatesaas-grafana-health-snapshot${local.suffix}"
  sop_aws_network_name     = "privatesaas-aws-network-snapshot${local.suffix}"
  sop_firewall_review_name = "privatesaas-firewall-policy-review${local.suffix}"

  grafana_integration_name  = "${local.module_prefix}-grafana${local.suffix}"
  aws_integration_name      = "${local.module_prefix}-aws${local.suffix}"
  paloalto_integration_name = "${local.module_prefix}-paloalto${local.suffix}"

  provision_grafana = (
    (trimspace(var.grafana_token) != "" || trimspace(var.grafana_secret_id) != "")
    && trimspace(var.existing_grafana_integration_name) == ""
  )
  provision_aws = (
    trimspace(var.aws_secret_id) != ""
    && trimspace(var.existing_aws_integration_name) == ""
  )
  provision_paloalto = (
    (
      trimspace(var.paloalto_secret_id) != ""
      || (trimspace(var.paloalto_management_url) != "" && trimspace(var.paloalto_api_key) != "")
      || (trimspace(var.paloalto_management_url) != "" && trimspace(var.paloalto_username) != "" && trimspace(var.paloalto_password) != "")
    )
    && trimspace(var.existing_paloalto_integration_name) == ""
  )

  resolved_grafana_integration_name = trimspace(var.existing_grafana_integration_name) != "" ? var.existing_grafana_integration_name : (
    local.provision_grafana ? module.grafana_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_paloalto_integration_name = trimspace(var.existing_paloalto_integration_name) != "" ? var.existing_paloalto_integration_name : (
    local.provision_paloalto ? module.paloalto_integration[0].integration_name : ""
  )

  severities_rego_literals     = join(", ", [for s in var.alert_ingest_allowed_severities : format("%q", lower(s))])
  environments_rego_literals   = join(", ", [for e in var.alert_ingest_allowed_environments : format("%q", lower(e))])
  namespaces_rego_literals     = join(", ", [for n in var.alert_ingest_allowed_namespaces : format("%q", lower(n))])
  blocked_alerts_rego_literals = join(", ", [for b in var.alert_ingest_blocked_alert_names : format("%q", lower(b))])

  alert_ingest_filter_rego = trimspace(templatefile("${path.module}/templates/alert-ingest-filter.rego.tftpl", {
    severities_gate_enabled           = length(var.alert_ingest_allowed_severities) > 0
    severities_rego_literals          = local.severities_rego_literals
    environments_gate_enabled         = length(var.alert_ingest_allowed_environments) > 0
    environments_rego_literals        = local.environments_rego_literals
    namespaces_gate_enabled           = length(var.alert_ingest_allowed_namespaces) > 0
    namespaces_rego_literals          = local.namespaces_rego_literals
    blocked_gate_enabled              = length(var.alert_ingest_blocked_alert_names) > 0
    blocked_alert_names_rego_literals = local.blocked_alerts_rego_literals
  }))

  firewall_template_vars = {
    paloalto_vsys                  = var.paloalto_vsys
    paloalto_device_group_hints    = jsonencode(var.paloalto_device_group_hints)
    private_saas_environment_label = var.private_saas_environment_label
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
  description        = "Grafana integration owned by ${local.agent_investigator_name} (PrivateSaaS incident investigation)."
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
  description        = "AWS integration owned by ${local.agent_remediator_name} (PrivateSaaS bounded remediation)."
}

module "paloalto_integration" {
  count  = local.provision_paloalto ? 1 : 0
  source = "../aios-integration-paloalto"

  integration_name   = local.paloalto_integration_name
  management_url     = var.paloalto_management_url
  api_key            = var.paloalto_api_key
  username           = var.paloalto_username
  password           = var.paloalto_password
  existing_secret_id = var.paloalto_secret_id
  integration_type   = var.paloalto_integration_type
  description        = "Palo Alto integration owned by ${local.agent_investigator_name} (PrivateSaaS firewall path analysis)."
}

resource "terraform_data" "grafana_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_grafana_integration_name) != ""
      error_message = "aios-agent-privatesaas-devops-sre needs a Grafana Guild integration: provide `grafana_token`/`grafana_secret_id`, or `existing_grafana_integration_name`."
    }
  }
}

resource "terraform_data" "aws_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_aws_integration_name) != ""
      error_message = "aios-agent-privatesaas-devops-sre needs an AWS Guild integration: provide `aws_secret_id` (the module provisions one) or `existing_aws_integration_name`."
    }
  }
}

resource "terraform_data" "paloalto_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_paloalto_integration_name) != ""
      error_message = "aios-agent-privatesaas-devops-sre needs a Palo Alto Guild integration: provide inline credentials, `paloalto_secret_id`, or `existing_paloalto_integration_name`."
    }
  }
}

# =============================================================================
# Agents
# =============================================================================

resource "sg_agent" "grafana_alert_ingest" {
  name        = local.agent_alert_ingest_name
  persona     = file("${path.module}/personas/grafana-alert-ingest.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_grafana_integration_name,
  ])
}

resource "sg_agent" "privatesaas_investigator" {
  name        = local.agent_investigator_name
  persona     = file("${path.module}/personas/privatesaas-investigator.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_grafana_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_paloalto_integration_name,
  ])
}

resource "sg_agent" "privatesaas_remediator" {
  name        = local.agent_remediator_name
  persona     = file("${path.module}/personas/privatesaas-remediator.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = compact([
      local.resolved_aws_integration_name != "" ? "${local.resolved_aws_integration_name}_test_connection" : "",
    ])
  }

  integrations = compact([
    local.resolved_aws_integration_name,
    local.resolved_grafana_integration_name,
    local.resolved_paloalto_integration_name,
  ])
}

# =============================================================================
# Agent budgets
# =============================================================================

resource "sg_agent_budget" "grafana_alert_ingest" {
  agent_name  = sg_agent.grafana_alert_ingest.name
  limit_usd   = var.agent_budgets.alert_ingest
  period_type = "daily"
}

resource "sg_agent_budget" "privatesaas_investigator" {
  agent_name  = sg_agent.privatesaas_investigator.name
  limit_usd   = var.agent_budgets.investigator
  period_type = "daily"
}

resource "sg_agent_budget" "privatesaas_remediator" {
  agent_name  = sg_agent.privatesaas_remediator.name
  limit_usd   = var.agent_budgets.remediator
  period_type = "daily"
}

# =============================================================================
# Policy attachments
# =============================================================================

resource "sg_agent_policy_attachment" "grafana_alert_ingest_dangerous_ops" {
  agent_name = sg_agent.grafana_alert_ingest.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "privatesaas_investigator_dangerous_ops" {
  agent_name = sg_agent.privatesaas_investigator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "privatesaas_remediator_dangerous_ops" {
  agent_name = sg_agent.privatesaas_remediator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "privatesaas_remediator_sre_remediation" {
  count      = local.attach_policy.sre_remediation ? 1 : 0
  agent_name = sg_agent.privatesaas_remediator.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "privatesaas_remediator_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate ? 1 : 0
  agent_name = sg_agent.privatesaas_remediator.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

# =============================================================================
# Runbooks
# =============================================================================

resource "sg_runbook_sop" "alert_normalization" {
  name        = local.sop_normalize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-alert-normalization.md", {}))
}

resource "sg_runbook_sop" "grafana_signals" {
  name        = local.sop_grafana_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-grafana-signals.md", {}))
}

resource "sg_runbook_sop" "aws_correlation" {
  name        = local.sop_aws_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-aws-correlation.md", {}))
}

resource "sg_runbook_sop" "firewall_path_analysis" {
  name        = local.sop_firewall_path_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-firewall-path-analysis.md", local.firewall_template_vars))
}

resource "sg_runbook_sop" "incident_synthesis" {
  name        = local.sop_synthesize_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-incident-synthesis.md", local.firewall_template_vars))
}

resource "sg_runbook_sop" "recommend_remediation" {
  name        = local.sop_remediate_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-recommend-remediation.md", {}))
}

resource "sg_runbook_sop" "grafana_health_snapshot" {
  name        = local.sop_grafana_health_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-grafana-health-snapshot.md", {}))
}

resource "sg_runbook_sop" "aws_network_snapshot" {
  name        = local.sop_aws_network_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-aws-network-snapshot.md", local.firewall_template_vars))
}

resource "sg_runbook_sop" "firewall_policy_review" {
  name        = local.sop_firewall_review_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-firewall-policy-review.md", local.firewall_template_vars))
}

# =============================================================================
# Workflow — PrivateSaaS incident response
# =============================================================================

resource "sg_workflow" "privatesaas_incident_response" {
  name        = local.workflow_incident_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-privatesaas-incident-response.md", local.firewall_template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "40"
  }

  triggers = [
    { field = "source", values = ["grafana"], type = "active", source = "grafana" },
    { field = "incident_title_contains", values = ["privatesaas", "vpc", "firewall", "connectivity"], type = "passive" },
  ]

  required_inputs = ["alert_name"]
  optional_inputs = ["environment", "namespace", "service", "severity"]

  runbook_refs = [
    sg_runbook_sop.alert_normalization.name,
    sg_runbook_sop.grafana_signals.name,
    sg_runbook_sop.aws_correlation.name,
    sg_runbook_sop.firewall_path_analysis.name,
    sg_runbook_sop.incident_synthesis.name,
    sg_runbook_sop.recommend_remediation.name,
  ]

  example_queries = [
    "Grafana critical alert in prod-vpc — investigate ECS latency and firewall path",
    "PrivateSaaS connectivity failure — correlate AWS changes with PAN-OS traffic logs",
    "Recommend safe AWS remediation for staging namespace alert with firewall deny findings",
  ]

  stages = [
    { stage_id = "grafana-ingest-filter", description = "Deterministic Rego filter on raw Grafana webhook payload (severity, environment/namespace allowlists; blocked alert names).", required = true },
    { stage_id = "normalize-alert", description = "Parse Grafana alert and emit normalized_alert JSON for downstream stages.", required = true },
    { stage_id = "collect-grafana-signals", description = "Query Grafana dashboards and Prometheus for incident-window metrics.", required = true },
    { stage_id = "correlate-aws-changes", description = "Inspect ECS/EKS/EC2 and CloudTrail around the incident window.", required = true },
    { stage_id = "analyze-firewall-path", description = "PAN-OS traffic/threat logs, policy hit, session analysis (read-only).", required = true },
    { stage_id = "synthesize-incident-report", description = "DevOps/SRE summary with network + infra correlation.", required = true },
    { stage_id = "remediation-safety-gate", description = "Inline Rego blocks P1/SEV1 auto-remediation.", required = true },
    { stage_id = "recommend-remediation", description = "Safe AWS actions only; firewall section = recommendations + change ticket text, no commits.", required = true },
  ]

  stage_bindings = [
    {
      stage_id    = "grafana-ingest-filter"
      action_type = "policy_check"
      action_config = {
        inline_rego = local.alert_ingest_filter_rego
      }
    },
    {
      stage_id         = "normalize-alert"
      agent_ref        = sg_agent.grafana_alert_ingest.name
      stage_depends_on = ["grafana-ingest-filter"]
      runbook_refs     = [sg_runbook_sop.alert_normalization.name]
      skill_refs       = concat(["privatesaas-grafana-alert-normalize"], try(var.workflow_skill_refs["privatesaas-incident-response::normalize-alert"], []))
      note             = "Normalize inbound Grafana alert payload into stable incident envelope."
    },
    {
      stage_id         = "collect-grafana-signals"
      agent_ref        = sg_agent.privatesaas_investigator.name
      stage_depends_on = ["normalize-alert"]
      runbook_refs     = [sg_runbook_sop.grafana_signals.name]
      skill_refs       = concat(["privatesaas-grafana-signals"], try(var.workflow_skill_refs["privatesaas-incident-response::collect-grafana-signals"], []))
      note             = "Collect Grafana observability signals for the incident window."
    },
    {
      stage_id         = "correlate-aws-changes"
      agent_ref        = sg_agent.privatesaas_investigator.name
      stage_depends_on = ["collect-grafana-signals"]
      runbook_refs     = [sg_runbook_sop.aws_correlation.name]
      skill_refs       = concat(["privatesaas-aws-correlation"], try(var.workflow_skill_refs["privatesaas-incident-response::correlate-aws-changes"], []))
      note             = "Correlate AWS infrastructure changes with the incident window."
    },
    {
      stage_id         = "analyze-firewall-path"
      agent_ref        = sg_agent.privatesaas_investigator.name
      stage_depends_on = ["correlate-aws-changes"]
      runbook_refs     = [sg_runbook_sop.firewall_path_analysis.name]
      skill_refs       = concat(["privatesaas-firewall-path-analysis"], try(var.workflow_skill_refs["privatesaas-incident-response::analyze-firewall-path"], []))
      note             = "Read-only PAN-OS traffic/threat log and policy hit analysis."
    },
    {
      stage_id         = "synthesize-incident-report"
      agent_ref        = sg_agent.privatesaas_investigator.name
      stage_depends_on = ["analyze-firewall-path"]
      runbook_refs     = [sg_runbook_sop.incident_synthesis.name]
      skill_refs       = concat(["privatesaas-incident-synthesis"], try(var.workflow_skill_refs["privatesaas-incident-response::synthesize-incident-report"], []))
      note             = "Synthesize DevOps/SRE incident report with network + infra correlation."
    },
    {
      stage_id         = "remediation-safety-gate"
      action_type      = "policy_check"
      stage_depends_on = ["synthesize-incident-report"]
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
          is_critical_severity if { regex.match(`\bcritical\b`, _text) }

          deny contains "P1/SEV1 incident requires human-in-the-loop approval for auto-remediation" if {
              is_critical_severity
          }
        REGO
      }
    },
    {
      stage_id         = "recommend-remediation"
      agent_ref        = sg_agent.privatesaas_remediator.name
      stage_depends_on = ["remediation-safety-gate"]
      runbook_refs     = [sg_runbook_sop.recommend_remediation.name]
      skill_refs       = concat(["privatesaas-recommend-remediation"], try(var.workflow_skill_refs["privatesaas-incident-response::recommend-remediation"], []))
      note             = "Safe AWS remediation and firewall change-ticket recommendations (no PAN-OS rule pushes)."
    },
  ]
}

# =============================================================================
# Workflow — PrivateSaaS connectivity audit (read-only)
# =============================================================================

resource "sg_workflow" "privatesaas_connectivity_audit" {
  name        = local.workflow_audit_name
  domain      = "devops"
  description = trimspace(templatefile("${path.module}/templates/workflow-privatesaas-connectivity-audit.md", local.firewall_template_vars))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "30"
  }

  triggers = [
    { field = "incident_title_contains", values = ["connectivity", "audit", "network", "firewall"], type = "passive" },
  ]

  required_inputs = []
  optional_inputs = ["environment"]

  runbook_refs = [
    sg_runbook_sop.grafana_health_snapshot.name,
    sg_runbook_sop.aws_network_snapshot.name,
    sg_runbook_sop.firewall_policy_review.name,
  ]

  example_queries = [
    "Run PrivateSaaS connectivity audit — Grafana health, AWS network, firewall policies",
    "Review PAN-OS policy hygiene for prod-vpc PrivateSaaS environment",
  ]

  stages = [
    { stage_id = "grafana-health-snapshot", description = "Read-only Grafana datasource and alertmanager health snapshot.", required = true },
    { stage_id = "aws-network-snapshot", description = "Read-only AWS VPC/subnet/route/security group topology snapshot.", required = true },
    { stage_id = "firewall-policy-review", description = "Read-only PAN-OS policy inventory and hit count review.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "grafana-health-snapshot"
      agent_ref    = sg_agent.privatesaas_investigator.name
      runbook_refs = [sg_runbook_sop.grafana_health_snapshot.name]
      skill_refs   = concat(["privatesaas-grafana-health-snapshot"], try(var.workflow_skill_refs["privatesaas-connectivity-audit::grafana-health-snapshot"], []))
      note         = "Capture Grafana health snapshot for connectivity audit."
    },
    {
      stage_id         = "aws-network-snapshot"
      agent_ref        = sg_agent.privatesaas_investigator.name
      stage_depends_on = ["grafana-health-snapshot"]
      runbook_refs     = [sg_runbook_sop.aws_network_snapshot.name]
      skill_refs       = concat(["privatesaas-aws-network-snapshot"], try(var.workflow_skill_refs["privatesaas-connectivity-audit::aws-network-snapshot"], []))
      note             = "Capture AWS network topology snapshot."
    },
    {
      stage_id         = "firewall-policy-review"
      agent_ref        = sg_agent.privatesaas_investigator.name
      stage_depends_on = ["aws-network-snapshot"]
      runbook_refs     = [sg_runbook_sop.firewall_policy_review.name]
      skill_refs       = concat(["privatesaas-firewall-policy-review"], try(var.workflow_skill_refs["privatesaas-connectivity-audit::firewall-policy-review"], []))
      note             = "Read-only PAN-OS policy review for connectivity audit."
    },
  ]
}

# =============================================================================
# Grafana webhook ingress
# =============================================================================

resource "sg_webhook" "grafana_privatesaas_alerts" {
  count = var.enable_grafana_webhook ? 1 : 0

  name          = local.webhook_name
  target_type   = "workflow"
  target_name   = sg_workflow.privatesaas_incident_response.name
  action        = "A Grafana alert fired for the PrivateSaaS environment. Parse the webhook JSON, apply ingest filters, investigate with Grafana/AWS/PAN-OS, synthesize an incident report, and recommend safe remediation when allowed."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
