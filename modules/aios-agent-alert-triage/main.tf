terraform {
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.23, < 0.2.0"
    }
  }
}

locals {
  module_prefix = "alert-triage"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_coordinator_name  = "alert-triage-coordinator${local.suffix}"
  agent_alert_ingest_name = "grafana-alert-ingest${local.suffix}"
  agent_investigator_name = "rca-investigator${local.suffix}"

  workflow_name = "cross-platform-alert-triage${local.suffix}"
  webhook_name  = "grafana-alert-receiver${local.suffix}"

  sop_routing_name          = "grafana-alert-routing-sop${local.suffix}"
  sop_normalize_name        = "alert-triage-normalization${local.suffix}"
  sop_search_prior_name     = "alert-triage-search-prior-incidents${local.suffix}"
  sop_classify_name         = "alert-triage-symptom-cause${local.suffix}"
  sop_grafana_signals_name  = "alert-triage-grafana-signals${local.suffix}"
  sop_query_probe_name      = "alert-triage-grafana-query-probe${local.suffix}"
  sop_datasource_probe_name = "alert-triage-grafana-datasource-probe${local.suffix}"
  sop_noise_hygiene_name    = "alert-triage-grafana-noise-hygiene${local.suffix}"
  sop_k8s_enrichment_name   = "alert-triage-k8s-enrichment${local.suffix}"
  sop_cross_signal_name     = "alert-triage-cross-signal-investigation${local.suffix}"
  sop_hypothesis_tree_name  = "alert-triage-hypothesis-tree-rca${local.suffix}"
  sop_synthesize_name       = "alert-triage-synthesize-rca${local.suffix}"
  sop_persist_memory_name   = "alert-triage-persist-incident-memory${local.suffix}"
  sop_publish_slack_name    = "alert-triage-publish-slack-rca${local.suffix}"

  grafana_integration_name = "${local.module_prefix}-grafana${local.suffix}"
  slack_integration_name   = "${local.module_prefix}-slack${local.suffix}"
  aws_integration_name     = "${local.module_prefix}-aws${local.suffix}"
  github_integration_name  = "${local.module_prefix}-github${local.suffix}"

  knowledge_base_name = "${local.module_prefix}-rca-kb${local.suffix}"

  provision_grafana = trimspace(var.grafana_secret_id) != "" && trimspace(var.existing_grafana_integration_name) == ""
  provision_slack   = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""
  provision_aws = (
    trimspace(var.aws_secret_id) != ""
    && trimspace(var.existing_aws_integration_name) == ""
  )
  provision_github = (
    (trimspace(var.github_token) != "" || trimspace(var.github_secret_id) != "")
    && trimspace(var.existing_github_integration_name) == ""
  )

  resolved_grafana_integration_name = trimspace(var.existing_grafana_integration_name) != "" ? var.existing_grafana_integration_name : (
    local.provision_grafana ? module.grafana_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_aws_integration_name = trimspace(var.existing_aws_integration_name) != "" ? var.existing_aws_integration_name : (
    local.provision_aws ? module.aws_integration[0].integration_name : ""
  )
  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )

  grafana_tool_prefix = local.resolved_grafana_integration_name
  github_tool_prefix  = local.resolved_github_integration_name
  aws_tool_prefix     = local.resolved_aws_integration_name

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

  investigation_template_vars = {
    github_default_org    = var.github_default_org
    github_default_repos  = jsonencode(var.github_default_repos)
    aws_ecs_cluster_hints = jsonencode(var.aws_ecs_cluster_hints)
    aws_region            = var.aws_region
  }

  remote_runner_names = (
    var.create_remote_runner
    && var.remote_runner_attach_to_agent
    && trimspace(var.remote_runner_name) != ""
    && length(module.remote_runner) > 0
  ) ? toset([module.remote_runner[0].runner_name]) : null

  attach_policy = {
    data_risk_pii = try(var.policy_create_flags.data_risk_pii, false)
  }

  ingest_integrations = compact([
    local.resolved_grafana_integration_name,
    local.resolved_slack_integration_name,
  ])

  investigator_integrations = compact([
    local.resolved_grafana_integration_name,
    local.resolved_aws_integration_name,
    local.resolved_github_integration_name,
  ])

  coordinator_integrations = compact([
    local.resolved_grafana_integration_name,
    local.resolved_slack_integration_name,
  ])
}

# =============================================================================
# Integration submodules
# =============================================================================

module "grafana_integration" {
  count  = local.provision_grafana ? 1 : 0
  source = "../aios-integration-grafana"

  integration_name   = local.grafana_integration_name
  existing_secret_id = var.grafana_secret_id
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

module "aws_integration" {
  count  = local.provision_aws ? 1 : 0
  source = "../aios-integration-aws"

  integration_name   = local.aws_integration_name
  existing_secret_id = var.aws_secret_id
  aws_region         = var.aws_region
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  github_token       = var.github_token
  existing_secret_id = var.github_secret_id
}

module "remote_runner" {
  count  = trimspace(var.remote_runner_name) != "" ? 1 : 0
  source = "../aios-remote-runner"

  create_runner = var.create_remote_runner
  name          = trimspace(var.remote_runner_name)
  description   = trimspace(var.remote_runner_description) != "" ? trimspace(var.remote_runner_description) : "Remote runner for ${local.agent_investigator_name} (K8s enrichment behind customer firewall)."
  labels        = var.remote_runner_labels
}

resource "terraform_data" "grafana_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_grafana_integration_name) != ""
      error_message = "aios-agent-alert-triage needs a Grafana integration: provide grafana_secret_id or existing_grafana_integration_name."
    }
  }
}

resource "terraform_data" "slack_integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_slack_integration_name) != ""
      error_message = "aios-agent-alert-triage needs a Slack integration: provide slack_secret_id or existing_slack_integration_name."
    }
  }
}

resource "terraform_data" "remote_runner_name_required" {
  lifecycle {
    precondition {
      condition     = !var.create_remote_runner || trimspace(var.remote_runner_name) != ""
      error_message = "create_remote_runner requires a non-empty remote_runner_name."
    }
  }
}

# =============================================================================
# Optional knowledge base
# =============================================================================

resource "sg_knowledge_base" "grafana_alert_rca" {
  count = var.enable_knowledge_base ? 1 : 0

  name        = local.knowledge_base_name
  description = "Static postmortems and Grafana alert RCA reference documents for alert-triage workflows."
}

# =============================================================================
# Agents
# =============================================================================

resource "sg_agent" "grafana_alert_ingest" {
  name        = local.agent_alert_ingest_name
  persona     = file("${path.module}/personas/grafana-alert-ingest.md")
  model_names = compact(var.model_names)

  integrations = local.ingest_integrations

  knowledge = {
    memory_enabled = true
    graph_enabled  = true
  }
}

resource "sg_agent" "rca_investigator" {
  name        = local.agent_investigator_name
  persona     = file("${path.module}/personas/rca-investigator.md")
  model_names = compact(var.model_names)

  integrations   = local.investigator_integrations
  remote_runners = local.remote_runner_names

  knowledge = {
    memory_enabled = true
    graph_enabled  = true
  }
}

resource "sg_agent" "alert_triage_coordinator" {
  name        = local.agent_coordinator_name
  persona     = file("${path.module}/personas/alert-triage-coordinator.md")
  model_names = compact(var.model_names)

  integrations = local.coordinator_integrations
}

resource "sg_agent_budget" "grafana_alert_ingest" {
  agent_name  = sg_agent.grafana_alert_ingest.name
  limit_usd   = var.agent_budgets.alert_ingest
  period_type = "daily"
}

resource "sg_agent_budget" "rca_investigator" {
  agent_name  = sg_agent.rca_investigator.name
  limit_usd   = var.agent_budgets.investigator
  period_type = "daily"
}

resource "sg_agent_budget" "alert_triage_coordinator" {
  agent_name  = sg_agent.alert_triage_coordinator.name
  limit_usd   = var.agent_budgets.coordinator
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "grafana_alert_ingest_dangerous_ops" {
  agent_name = sg_agent.grafana_alert_ingest.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "rca_investigator_dangerous_ops" {
  agent_name = sg_agent.rca_investigator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "coordinator_dangerous_ops" {
  agent_name = sg_agent.alert_triage_coordinator.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "grafana_alert_ingest_data_risk" {
  count      = local.attach_policy.data_risk_pii && trimspace(var.policy_ids.data_risk_pii) != "" ? 1 : 0
  agent_name = sg_agent.grafana_alert_ingest.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_agent_policy_attachment" "rca_investigator_data_risk" {
  count      = local.attach_policy.data_risk_pii && trimspace(var.policy_ids.data_risk_pii) != "" ? 1 : 0
  agent_name = sg_agent.rca_investigator.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

# =============================================================================
# Runbook SOPs
# =============================================================================

resource "sg_runbook_sop" "grafana_alert_routing" {
  name        = local.sop_routing_name
  approve     = true
  description = <<-EOT
    Triages an incoming Grafana alert by checking labels and routing to the correct cloud provider skill when RCA confidence is low.

    Steps:
    1) Review structured RCA JSON and confidence from upstream stages.
    2) When confidence is low or network/infra labels dominate, dynamically resolve the best-fit cloud agent.
    3) Summarize escalation findings for Slack publish.
  EOT
}

resource "sg_runbook_sop" "alert_normalization" {
  name        = local.sop_normalize_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-alert-normalization.md"))
}

resource "sg_runbook_sop" "search_prior_incidents" {
  name        = local.sop_search_prior_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-search-prior-incidents.md"))
}

resource "sg_runbook_sop" "symptom_cause_classification" {
  name        = local.sop_classify_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-symptom-cause-classification.md"))
}

resource "sg_runbook_sop" "grafana_signals" {
  name        = local.sop_grafana_signals_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-grafana-signals.md"))
}

resource "sg_runbook_sop" "grafana_query_probe" {
  name        = local.sop_query_probe_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-grafana-query-probe.md.tftpl", local.investigation_template_vars))
}

resource "sg_runbook_sop" "grafana_datasource_probe" {
  name        = local.sop_datasource_probe_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-grafana-datasource-probe.md"))
}

resource "sg_runbook_sop" "grafana_noise_hygiene" {
  name        = local.sop_noise_hygiene_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-grafana-noise-hygiene.md"))
}

resource "sg_runbook_sop" "k8s_enrichment" {
  name        = local.sop_k8s_enrichment_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-k8s-enrichment.md.tftpl", local.investigation_template_vars))
}

resource "sg_runbook_sop" "cross_signal_investigation" {
  name        = local.sop_cross_signal_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-cross-signal-investigation.md.tftpl", local.investigation_template_vars))
}

resource "sg_runbook_sop" "hypothesis_tree_rca" {
  name        = local.sop_hypothesis_tree_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-hypothesis-tree-rca.md.tftpl", local.investigation_template_vars))
}

resource "sg_runbook_sop" "synthesize_rca" {
  name        = local.sop_synthesize_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-synthesize-rca.md"))
}

resource "sg_runbook_sop" "persist_incident_memory" {
  name        = local.sop_persist_memory_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-persist-incident-memory.md"))
}

resource "sg_runbook_sop" "publish_slack_rca" {
  name        = local.sop_publish_slack_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-publish-slack-rca.md"))
}

# =============================================================================
# Workflow — Grafana alert RCA pipeline
# =============================================================================

resource "sg_workflow" "alert_triage_pipeline" {
  name        = local.workflow_name
  domain      = "incident-response"
  description = "Tiered Grafana alert-storm triage: ingest filter, prior-incident memory, enrichment, ReAcTree hypothesis RCA, optional cloud escalation, Slack publish."
  approve     = true

  metadata = {
    planner_max_tool_iterations = 50
  }

  triggers = [
    { field = "source", values = ["grafana"], type = "active", source = "grafana" },
  ]

  required_inputs = ["alert_uid"]
  optional_inputs = ["alert_name", "rule_uid", "namespace", "service", "severity"]

  runbook_refs = [
    sg_runbook_sop.alert_normalization.name,
    sg_runbook_sop.search_prior_incidents.name,
    sg_runbook_sop.symptom_cause_classification.name,
    sg_runbook_sop.grafana_signals.name,
    sg_runbook_sop.grafana_query_probe.name,
    sg_runbook_sop.grafana_datasource_probe.name,
    sg_runbook_sop.k8s_enrichment.name,
    sg_runbook_sop.cross_signal_investigation.name,
    sg_runbook_sop.hypothesis_tree_rca.name,
    sg_runbook_sop.synthesize_rca.name,
    sg_runbook_sop.persist_incident_memory.name,
    sg_runbook_sop.grafana_alert_routing.name,
    sg_runbook_sop.publish_slack_rca.name,
  ]

  example_queries = [
    "Grafana critical alert on payments-api — symptom/cause RCA with PromQL probe and Slack summary",
    "Alert storm on checkout namespace — search prior incidents and rank deploy vs capacity hypotheses",
    "Low-confidence network alert — escalate to cloud SRE after ReAcTree investigation",
  ]

  stages = [
    { stage_id = "grafana-ingest-filter", description = "Deterministic Rego filter on raw Grafana webhook payload.", required = true },
    { stage_id = "normalize-alert", description = "Parse Grafana alert and emit normalized_alert JSON.", required = true },
    { stage_id = "search-prior-incidents", description = "memory_search + graph_query on shared:incidents for similar alerts.", required = true },
    { stage_id = "classify-symptom-cause", description = "Tag alert as symptom vs cause-based for storm triage.", required = true },
    { stage_id = "collect-grafana-signals", description = "Golden signals, related alerts, dashboard links for incident window.", required = true },
    { stage_id = "probe-grafana-queries", description = "get_alert_rule + query_metric + datasource probe; clarity verdict.", required = true },
    { stage_id = "enrich-k8s-context", description = "Remote-runner kubectl enrichment when configured.", required = true },
    { stage_id = "cross-signal-investigate", description = "ReAcTree parallel hypothesis investigation with AWS/GitHub correlation.", required = true },
    { stage_id = "synthesize-rca", description = "Structured RCA JSON with timeline, root cause, evidence links.", required = true },
    { stage_id = "persist-incident-memory", description = "memory_store + graph_store to shared:incidents when confidence ≥ medium.", required = true },
    { stage_id = "cloud-triage", description = "Dynamic cloud agent escalation when confidence is low or infra/network scope.", required = true },
    { stage_id = "notify-slack", description = "Post RCA narrative to Slack.", required = true },
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
      skill_refs       = concat(["sre-grafana-alert-ingest", "sre-alert-normalization"], try(var.workflow_skill_refs["${local.workflow_name}::normalize-alert"], []))
      note             = "Normalize inbound Grafana alert into stable incident envelope."
    },
    {
      stage_id         = "search-prior-incidents"
      agent_ref        = sg_agent.grafana_alert_ingest.name
      stage_depends_on = ["normalize-alert"]
      runbook_refs     = [sg_runbook_sop.search_prior_incidents.name]
      skill_refs       = concat(["sre-prior-incident-search"], try(var.workflow_skill_refs["${local.workflow_name}::search-prior-incidents"], []))
      note             = "Search shared:incidents for similar prior alerts before enrichment."
    },
    {
      stage_id         = "classify-symptom-cause"
      agent_ref        = sg_agent.grafana_alert_ingest.name
      stage_depends_on = ["search-prior-incidents"]
      runbook_refs     = [sg_runbook_sop.symptom_cause_classification.name]
      skill_refs       = concat(["sre-symptom-cause-classification"], try(var.workflow_skill_refs["${local.workflow_name}::classify-symptom-cause"], []))
      note             = "Classify symptom vs cause-based alert role for storm triage."
    },
    {
      stage_id         = "collect-grafana-signals"
      agent_ref        = sg_agent.rca_investigator.name
      stage_depends_on = ["classify-symptom-cause"]
      runbook_refs     = [sg_runbook_sop.grafana_signals.name]
      skill_refs       = concat(["sre-grafana-signals", "sre-golden-signals"], try(var.workflow_skill_refs["${local.workflow_name}::collect-grafana-signals"], []))
      note             = "Collect Grafana observability signals for the incident window."
    },
    {
      stage_id         = "probe-grafana-queries"
      agent_ref        = sg_agent.rca_investigator.name
      stage_depends_on = ["collect-grafana-signals"]
      runbook_refs = [
        sg_runbook_sop.grafana_query_probe.name,
        sg_runbook_sop.grafana_datasource_probe.name,
      ]
      skill_refs = concat(["sre-grafana-query-probe"], try(var.workflow_skill_refs["${local.workflow_name}::probe-grafana-queries"], []))
      note       = "Re-run alert-rule PromQL via get_alert_rule + query_metric; probe datasource health."
    },
    {
      stage_id         = "enrich-k8s-context"
      agent_ref        = sg_agent.rca_investigator.name
      stage_depends_on = ["probe-grafana-queries"]
      runbook_refs     = [sg_runbook_sop.k8s_enrichment.name]
      skill_refs       = concat(["sre-k8s-enrichment"], try(var.workflow_skill_refs["${local.workflow_name}::enrich-k8s-context"], []))
      note             = trimspace(var.remote_runner_name) != "" ? "K8s enrichment via remote runner kubectl." : "Skip k8s enrichment — remote_runner_name not set; emit skipped k8s_context."
    },
    {
      stage_id         = "cross-signal-investigate"
      agent_ref        = sg_agent.rca_investigator.name
      stage_depends_on = ["enrich-k8s-context"]
      runbook_refs = [
        sg_runbook_sop.cross_signal_investigation.name,
        sg_runbook_sop.hypothesis_tree_rca.name,
      ]
      spawn_contracts = local.spawn_contracts_hypothesis_tree
      skill_refs      = concat(["sre-cross-signal-investigation", "sre-hypothesis-tree-rca"], try(var.workflow_skill_refs["${local.workflow_name}::cross-signal-investigate"], []))
      note            = "Coordinator spawns parallel hypothesis subagents via create_agent; merge investigation_report."
    },
    {
      stage_id         = "synthesize-rca"
      agent_ref        = sg_agent.rca_investigator.name
      stage_depends_on = ["cross-signal-investigate"]
      runbook_refs     = [sg_runbook_sop.synthesize_rca.name]
      skill_refs       = concat(["sre-rca-synthesis"], try(var.workflow_skill_refs["${local.workflow_name}::synthesize-rca"], []))
      note             = "Synthesize structured RCA JSON from investigation evidence."
    },
    {
      stage_id         = "persist-incident-memory"
      agent_ref        = sg_agent.rca_investigator.name
      stage_depends_on = ["synthesize-rca"]
      runbook_refs     = [sg_runbook_sop.persist_incident_memory.name]
      skill_refs       = concat(["sre-persist-incident-memory"], try(var.workflow_skill_refs["${local.workflow_name}::persist-incident-memory"], []))
      note             = "Write RCA summary to shared:incidents via memory_store and graph_store when confidence ≥ medium."
    },
    {
      stage_id         = "cloud-triage"
      agent_ref        = sg_agent.alert_triage_coordinator.name
      stage_depends_on = ["persist-incident-memory"]
      runbook_refs     = [sg_runbook_sop.grafana_alert_routing.name]
      skill_refs       = concat(["sre-multi-cloud-triage", "sre-dynamic-agent-routing"], try(var.workflow_skill_refs["${local.workflow_name}::cloud-triage"], []))
      note             = "When RCA confidence is low or labels indicate network/infra scope, dynamically resolve best-fit cloud agent. Skip deep escalation when confidence is high."
    },
    {
      stage_id         = "notify-slack"
      agent_ref        = sg_agent.alert_triage_coordinator.name
      stage_depends_on = ["cloud-triage"]
      runbook_refs     = [sg_runbook_sop.publish_slack_rca.name]
      skill_refs       = concat(["sre-slack-incident-summary"], try(var.workflow_skill_refs["${local.workflow_name}::notify-slack"], []))
      note             = "Post structured RCA summary to Slack with evidence links."
    },
  ]
}

# =============================================================================
# Webhook Ingress
# =============================================================================

resource "sg_webhook" "grafana_alerts" {
  name        = local.webhook_name
  target_type = "workflow"
  target_name = sg_workflow.alert_triage_pipeline.name
  action      = "A Grafana alert fired. Apply ingest filters, search prior incidents, probe alert-rule queries, run hypothesis RCA, persist memory, and post summary to Slack."
  enabled     = true
}
