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
  module_prefix = "sre-ticket-resolution"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_intake_name       = "ticket-intake${local.suffix}"
  agent_investigator_name = "ticket-investigator${local.suffix}"
  agent_resolver_name     = "ticket-resolver${local.suffix}"

  workflow_ticket_name = "servicenow-ticket-resolution${local.suffix}"
  webhook_name         = "servicenow-ticket-receiver${local.suffix}"

  sop_enrich_name      = "ticket-enrichment${local.suffix}"
  sop_investigate_name = "ticket-investigation${local.suffix}"
  sop_propose_name     = "ticket-propose-resolution${local.suffix}"
  sop_resolve_name     = "ticket-resolution-notify${local.suffix}"

  servicenow_integration_name = "${local.module_prefix}-servicenow${local.suffix}"
  aws_integration_name        = "${local.module_prefix}-aws${local.suffix}"
  grafana_integration_name    = "${local.module_prefix}-grafana${local.suffix}"
  slack_integration_name      = "${local.module_prefix}-slack${local.suffix}"

  provision_servicenow = (
    (
      (trimspace(var.servicenow_instance_url) != "" && trimspace(var.servicenow_username) != "" && trimspace(var.servicenow_password) != "")
      || trimspace(var.servicenow_secret_id) != ""
    )
    && trimspace(var.existing_servicenow_integration_name) == ""
  )
  provision_aws = (
    trimspace(var.aws_secret_id) != ""
    && trimspace(var.existing_aws_integration_name) == ""
  )
  provision_grafana = (
    (trimspace(var.grafana_token) != "" || trimspace(var.grafana_secret_id) != "")
    && trimspace(var.existing_grafana_integration_name) == ""
  )
  provision_slack = (
    (trimspace(var.slack_bot_token) != "" || trimspace(var.slack_secret_id) != "")
    && trimspace(var.existing_slack_integration_name) == ""
  )

  resolved_servicenow_integration_name = trimspace(var.existing_servicenow_integration_name) != "" ? var.existing_servicenow_integration_name : (
    local.provision_servicenow ? module.servicenow_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_grafana_integration_name = trimspace(var.existing_grafana_integration_name) != "" ? var.existing_grafana_integration_name : (
    local.provision_grafana ? module.grafana_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )

  priorities_rego_literals                 = join(", ", [for p in var.ticket_ingest_allowed_priorities : format("%q", lower(p))])
  assignment_groups_rego_literals          = join(", ", [for g in var.ticket_ingest_allowed_assignment_groups : format("%q", lower(g))])
  categories_rego_literals                 = join(", ", [for c in var.ticket_ingest_allowed_categories : format("%q", lower(c))])
  blocked_assignment_groups_rego_literals  = join(", ", [for b in var.ticket_ingest_blocked_assignment_groups : format("%q", lower(b))])
  blocked_short_descriptions_rego_literals = join(", ", [for s in var.ticket_ingest_blocked_short_description_substrings : format("%q", lower(s))])

  ticket_ingest_filter_rego = trimspace(templatefile("${path.module}/templates/ticket-ingest-filter.rego.tftpl", {
    priorities_gate_enabled                  = length(var.ticket_ingest_allowed_priorities) > 0
    priorities_rego_literals                 = local.priorities_rego_literals
    assignment_groups_gate_enabled           = length(var.ticket_ingest_allowed_assignment_groups) > 0
    assignment_groups_rego_literals          = local.assignment_groups_rego_literals
    categories_gate_enabled                  = length(var.ticket_ingest_allowed_categories) > 0
    categories_rego_literals                 = local.categories_rego_literals
    blocked_assignment_groups_gate_enabled   = length(var.ticket_ingest_blocked_assignment_groups) > 0
    blocked_assignment_groups_rego_literals  = local.blocked_assignment_groups_rego_literals
    blocked_short_descriptions_gate_enabled  = length(var.ticket_ingest_blocked_short_description_substrings) > 0
    blocked_short_descriptions_rego_literals = local.blocked_short_descriptions_rego_literals
  }))

  resolution_runbook_template_vars = {
    slack_channel_hint = var.slack_channel_hint
  }

  attach_policy = {
    sre_remediation = try(var.policy_create_flags.sre_remediation, true)
    prod_write_gate = try(var.policy_create_flags.prod_write_gate, true)
  }
}

# =============================================================================
# Integration submodules
# =============================================================================

module "servicenow_integration" {
  count  = local.provision_servicenow ? 1 : 0
  source = "../aios-integration-servicenow"

  integration_name   = local.servicenow_integration_name
  instance_url       = var.servicenow_instance_url
  username           = var.servicenow_username
  password           = var.servicenow_password
  existing_secret_id = var.servicenow_secret_id
  description        = "ServiceNow integration owned by ${local.agent_intake_name} (SRE ticket resolution)."
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
  description        = "AWS integration owned by ${local.agent_resolver_name} (SRE ticket remediation)."
}

module "grafana_integration" {
  count  = local.provision_grafana ? 1 : 0
  source = "../aios-integration-grafana"

  integration_name   = local.grafana_integration_name
  grafana_server     = var.grafana_server
  grafana_token      = var.grafana_token
  existing_secret_id = var.grafana_secret_id
  description        = "Grafana integration owned by ${local.agent_investigator_name} (SRE ticket investigation)."
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name     = local.slack_integration_name
  slack_bot_token      = var.slack_bot_token
  slack_signing_secret = var.slack_signing_secret
  slack_webhook_url    = var.slack_webhook_url
  existing_secret_id   = var.slack_secret_id
  description          = "Slack integration owned by ${local.agent_intake_name} (SRE ticket notifications)."
}

resource "terraform_data" "servicenow_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_servicenow_integration_name) != ""
      error_message = "aios-agent-sre-ticket-resolution needs a ServiceNow Guild integration: provide inline credentials, `servicenow_secret_id`, or `existing_servicenow_integration_name`."
    }
  }
}

resource "terraform_data" "aws_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_aws_integration_name) != ""
      error_message = "aios-agent-sre-ticket-resolution needs an AWS Guild integration: provide `aws_secret_id` (the module provisions one) or `existing_aws_integration_name`."
    }
  }
}

resource "terraform_data" "grafana_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_grafana_integration_name) != ""
      error_message = "aios-agent-sre-ticket-resolution needs a Grafana Guild integration: provide `grafana_token`/`grafana_secret_id`, or `existing_grafana_integration_name`."
    }
  }
}

resource "terraform_data" "slack_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_slack_integration_name) != ""
      error_message = "aios-agent-sre-ticket-resolution needs a Slack Guild integration: provide `slack_bot_token`/`slack_secret_id`, or `existing_slack_integration_name`."
    }
  }
}

# =============================================================================
# Agents
# =============================================================================

resource "sg_agent" "ticket_intake" {
  name        = local.agent_intake_name
  persona     = file("${path.module}/personas/ticket-intake.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_servicenow_integration_name,
    local.resolved_slack_integration_name,
  ])
}

resource "sg_agent" "ticket_investigator" {
  name        = local.agent_investigator_name
  persona     = file("${path.module}/personas/ticket-investigator.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_servicenow_integration_name,
    local.resolved_grafana_integration_name,
    local.resolved_aws_integration_name,
  ])
}

resource "sg_agent" "ticket_resolver" {
  name        = local.agent_resolver_name
  persona     = file("${path.module}/personas/ticket-resolver.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = compact([
      local.resolved_aws_integration_name != "" ? "${local.resolved_aws_integration_name}_test_connection" : "",
    ])
  }

  integrations = compact([
    local.resolved_servicenow_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_slack_integration_name,
  ])
}

# =============================================================================
# Agent budgets
# =============================================================================

resource "sg_agent_budget" "ticket_intake" {
  agent_name  = sg_agent.ticket_intake.name
  limit_usd   = var.agent_budgets.intake
  period_type = "daily"
}

resource "sg_agent_budget" "ticket_investigator" {
  agent_name  = sg_agent.ticket_investigator.name
  limit_usd   = var.agent_budgets.investigator
  period_type = "daily"
}

resource "sg_agent_budget" "ticket_resolver" {
  agent_name  = sg_agent.ticket_resolver.name
  limit_usd   = var.agent_budgets.resolver
  period_type = "daily"
}

# =============================================================================
# Policy attachments
# =============================================================================

resource "sg_agent_policy_attachment" "ticket_intake_dangerous_ops" {
  agent_name = sg_agent.ticket_intake.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "ticket_investigator_dangerous_ops" {
  agent_name = sg_agent.ticket_investigator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "ticket_resolver_dangerous_ops" {
  agent_name = sg_agent.ticket_resolver.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "ticket_resolver_sre_remediation" {
  count      = local.attach_policy.sre_remediation ? 1 : 0
  agent_name = sg_agent.ticket_resolver.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "ticket_resolver_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate ? 1 : 0
  agent_name = sg_agent.ticket_resolver.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

# =============================================================================
# Runbooks
# =============================================================================

resource "sg_runbook_sop" "ticket_enrichment" {
  name        = local.sop_enrich_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-ticket-enrichment.md", {}))
}

resource "sg_runbook_sop" "ticket_investigation" {
  name        = local.sop_investigate_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-ticket-investigation.md", {}))
}

resource "sg_runbook_sop" "propose_resolution" {
  name        = local.sop_propose_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-propose-resolution.md", {}))
}

resource "sg_runbook_sop" "ticket_resolution" {
  name        = local.sop_resolve_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-ticket-resolution.md", local.resolution_runbook_template_vars))
}

# =============================================================================
# Workflow — ServiceNow ticket resolution
# =============================================================================

resource "sg_workflow" "servicenow_ticket_resolution" {
  name        = local.workflow_ticket_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-servicenow-ticket-resolution.md", {}))
  approve     = true

  metadata = {
    planner_max_tool_iterations = "40"
  }

  triggers = [
    { field = "source", values = ["servicenow"], type = "active", source = "servicenow" },
    { field = "incident_title_contains", values = ["incident", "outage", "degraded"], type = "passive" },
  ]

  required_inputs = ["ticket_sys_id"]
  optional_inputs = ["number", "assignment_group", "category", "priority"]

  runbook_refs = [
    sg_runbook_sop.ticket_enrichment.name,
    sg_runbook_sop.ticket_investigation.name,
    sg_runbook_sop.propose_resolution.name,
    sg_runbook_sop.ticket_resolution.name,
  ]

  example_queries = [
    "ServiceNow INC0012345 — investigate API latency and remediate in AWS",
    "P3 ticket for checkout errors — query Grafana Prometheus and restart unhealthy ECS tasks",
    "Enrich SNOW ticket, investigate CloudWatch, propose safe scale-up",
  ]

  stages = [
    { stage_id = "ticket-ingest-filter", description = "Deterministic Rego filter on raw ServiceNow webhook payload (priority, assignment group, category allowlists; blocked groups and short_description substrings).", required = true },
    { stage_id = "enrich-ticket", description = "Parse ServiceNow ticket, add work notes, notify Slack, emit enriched_ticket JSON.", required = true },
    { stage_id = "investigate", description = "Query Grafana (Prometheus datasources) and AWS for root-cause evidence.", required = true },
    { stage_id = "propose-resolution", description = "Plan bounded AWS remediation with rollback and verification steps.", required = true },
    { stage_id = "resolution-safety-gate", description = "Inline Rego blocks auto-remediation when investigation or plan output reflects P1/Critical-class severity.", required = true },
    { stage_id = "resolve-and-notify", description = "Execute safe AWS actions, update ServiceNow, post Slack summary.", required = true },
  ]

  stage_bindings = [
    {
      stage_id    = "ticket-ingest-filter"
      action_type = "policy_check"
      action_config = {
        inline_rego = local.ticket_ingest_filter_rego
      }
    },
    {
      stage_id         = "enrich-ticket"
      agent_ref        = sg_agent.ticket_intake.name
      stage_depends_on = ["ticket-ingest-filter"]
      runbook_refs     = [sg_runbook_sop.ticket_enrichment.name]
      skill_refs       = concat(["sre-servicenow-ticket-enrich"], try(var.workflow_skill_refs["servicenow-ticket-resolution::enrich-ticket"], []))
      note             = "Enrich inbound ServiceNow ticket and notify Slack."
    },
    {
      stage_id         = "investigate"
      agent_ref        = sg_agent.ticket_investigator.name
      stage_depends_on = ["enrich-ticket"]
      runbook_refs     = [sg_runbook_sop.ticket_investigation.name]
      skill_refs       = concat(["sre-grafana-aws-ticket-investigation"], try(var.workflow_skill_refs["servicenow-ticket-resolution::investigate"], []))
      note             = "Cross-signal investigation using Grafana and AWS integrations."
    },
    {
      stage_id         = "propose-resolution"
      agent_ref        = sg_agent.ticket_resolver.name
      stage_depends_on = ["investigate"]
      runbook_refs     = [sg_runbook_sop.propose_resolution.name]
      skill_refs       = concat(["sre-aws-resolution-plan"], try(var.workflow_skill_refs["servicenow-ticket-resolution::propose-resolution"], []))
      note             = "Plan bounded AWS remediation without executing mutating actions."
    },
    {
      stage_id         = "resolution-safety-gate"
      action_type      = "policy_check"
      stage_depends_on = ["propose-resolution"]
      action_config = {
        inline_rego = <<-REGO
          package stage_gate

          import rego.v1

          default allow = true

          # Block auto-remediation for P1/Critical. Match word-boundary severity tokens (avoid p10, etc.).
          allow = false if { is_critical_severity }

          _text := lower(input.stage_input)

          is_critical_severity if { regex.match(`\bp1\b`, _text) }
          is_critical_severity if { regex.match(`\bcritical\b`, _text) }
          is_critical_severity if { regex.match(`\bsev[- ]?1\b`, _text) }
          is_critical_severity if { contains(_text, "priority: 1") }
          is_critical_severity if { contains(_text, "1 - critical") }

          deny contains "P1/Critical incident requires human-in-the-loop approval for AWS auto-remediation" if {
              is_critical_severity
          }
        REGO
      }
    },
    {
      stage_id         = "resolve-and-notify"
      agent_ref        = sg_agent.ticket_resolver.name
      stage_depends_on = ["resolution-safety-gate"]
      runbook_refs     = [sg_runbook_sop.ticket_resolution.name]
      skill_refs       = concat(["sre-aws-ticket-resolve-notify"], try(var.workflow_skill_refs["servicenow-ticket-resolution::resolve-and-notify"], []))
      note             = "Execute safe AWS remediation, update ServiceNow, and post Slack summary."
    },
  ]
}

# =============================================================================
# ServiceNow webhook ingress
# =============================================================================

resource "sg_webhook" "servicenow_ticket_receiver" {
  count = var.enable_servicenow_webhook ? 1 : 0

  name          = local.webhook_name
  target_type   = "workflow"
  target_name   = sg_workflow.servicenow_ticket_resolution.name
  action        = "A ServiceNow ticket was created or updated. Parse the webhook JSON, apply ingest filters, investigate with Grafana and AWS, propose and execute safe remediation when allowed, update ServiceNow, and notify Slack."
  enabled       = true
  allowed_cidrs = length(var.webhook_allowed_cidrs) > 0 ? var.webhook_allowed_cidrs : null
}
