terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.18, < 0.2.0" }
  }
}

locals {
  module_prefix = "sre"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_triage_name             = "alert-triage-analyst${local.suffix}"
  agent_change_correlation_name = "change-correlation-analyst${local.suffix}"
  agent_auto_remediation_name   = "auto-remediation-engineer${local.suffix}"
  agent_risk_posture_name       = "risk-posture-assessor${local.suffix}"
  agent_incident_name           = "incident-commander${local.suffix}"

  workflow_incident_name       = "incident-response${local.suffix}"
  workflow_incident_quick_name = "incident-triage${local.suffix}"

  grafana_integration_name = "${local.module_prefix}-grafana${local.suffix}"
  slack_integration_name   = "${local.module_prefix}-slack${local.suffix}"
  linear_integration_name  = "${local.module_prefix}-linear${local.suffix}"

  provision_grafana = trimspace(var.grafana_secret_id) != "" && trimspace(var.existing_grafana_integration_name) == ""
  provision_slack   = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""
  provision_linear  = trimspace(var.linear_credential_provider_id) != "" && trimspace(var.existing_linear_integration_name) == ""

  resolved_grafana_integration_name = trimspace(var.existing_grafana_integration_name) != "" ? var.existing_grafana_integration_name : (
    local.provision_grafana ? module.grafana_integration[0].integration_name : ""
  )
  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_linear_integration_name = trimspace(var.existing_linear_integration_name) != "" ? var.existing_linear_integration_name : (
    local.provision_linear ? module.linear_integration[0].integration_name : ""
  )
}

module "grafana_integration" {
  count  = local.provision_grafana ? 1 : 0
  source = "../aios-integration-grafana"

  integration_name   = local.grafana_integration_name
  existing_secret_id = var.grafana_secret_id
  description        = "Grafana integration owned by the SRE module (incident triage + dashboard queries)."
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
  description        = "Slack integration owned by the SRE module (incident comms + war room channel ops)."
}

module "linear_integration" {
  count  = local.provision_linear ? 1 : 0
  source = "../aios-integration-linear"

  integration_name       = local.linear_integration_name
  credential_provider_id = var.linear_credential_provider_id
}

# =============================================================================
# AIOS SRE Agent Module
# =============================================================================
# Provisions 5 SRE agents (triage, change-correlation, auto-remediation,
# risk-posture, incident-commander), runbook SOPs, remediation patterns,
# evidence checklists, and the incident-response workflow.

# =============================================================================
# Agents
# =============================================================================

resource "sg_agent" "sre_triage" {
  name        = local.agent_triage_name
  persona     = file("${path.module}/personas/sre-triage.md")
  model_names = compact(var.model_names)

  integrations = compact([local.resolved_grafana_integration_name])
}

resource "sg_agent" "sre_change_correlation" {
  name        = local.agent_change_correlation_name
  persona     = file("${path.module}/personas/sre-change-correlation.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "sre_auto_remediation" {
  name        = local.agent_auto_remediation_name
  persona     = file("${path.module}/personas/sre-auto-remediation.md")
  model_names = compact(var.model_names)

  hitl = {
    always_allowed = ["run_shell"]
  }

  integrations = []
}

resource "sg_agent" "sre_risk_posture" {
  name        = local.agent_risk_posture_name
  persona     = file("${path.module}/personas/sre-risk-posture.md")
  model_names = compact(var.model_names)
}

resource "sg_agent" "sre_incident" {
  name        = local.agent_incident_name
  persona     = file("${path.module}/personas/sre-incident.md")
  model_names = compact(var.model_names)

  integrations = compact([
    local.resolved_grafana_integration_name,
    local.resolved_slack_integration_name,
    local.resolved_linear_integration_name,
  ])
}

# =============================================================================
# Agent Budgets
# =============================================================================

resource "sg_agent_budget" "sre_auto_remediation" {
  agent_name  = sg_agent.sre_auto_remediation.name
  limit_usd   = var.agent_budgets.auto_remediation
  period_type = "daily"
}

resource "sg_agent_budget" "sre_incident" {
  agent_name  = sg_agent.sre_incident.name
  limit_usd   = var.agent_budgets.incident
  period_type = "daily"
}

resource "sg_agent_budget" "sre_triage" {
  agent_name  = sg_agent.sre_triage.name
  limit_usd   = var.agent_budgets.triage
  period_type = "daily"
}

resource "sg_agent_budget" "sre_change_correlation" {
  agent_name  = sg_agent.sre_change_correlation.name
  limit_usd   = var.agent_budgets.change_correlation
  period_type = "daily"
}

resource "sg_agent_budget" "sre_risk_posture" {
  agent_name  = sg_agent.sre_risk_posture.name
  limit_usd   = var.agent_budgets.risk_posture
  period_type = "daily"
}

locals {
  attach_policy = {
    sre_remediation          = try(var.policy_create_flags.sre_remediation, true) && try(var.policy_ids.sre_remediation, "") != ""
    prod_write_gate          = try(var.policy_create_flags.prod_write_gate, true) && try(var.policy_ids.prod_write_gate, "") != ""
    tier0_service_protection = try(var.policy_create_flags.tier0_service_protection, true) && try(var.policy_ids.tier0_service_protection, "") != ""
    blast_radius_limit       = try(var.policy_create_flags.blast_radius_limit, true) && try(var.policy_ids.blast_radius_limit, "") != ""
    freeze_window            = try(var.policy_create_flags.freeze_window, true) && try(var.policy_ids.freeze_window, "") != ""
    data_risk_pii            = try(var.policy_create_flags.data_risk_pii, true) && try(var.policy_ids.data_risk_pii, "") != ""
    post_action_verification = try(var.policy_create_flags.post_action_verification, true) && try(var.policy_ids.post_action_verification, "") != ""
  }
}

# =============================================================================
# Policy Attachments
# =============================================================================

# --- sre_incident ---
resource "sg_agent_policy_attachment" "sre_incident_dangerous_ops" {
  agent_name = sg_agent.sre_incident.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_incident_remediation" {
  count      = local.attach_policy.sre_remediation ? 1 : 0
  agent_name = sg_agent.sre_incident.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_incident_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate ? 1 : 0
  agent_name = sg_agent.sre_incident.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_incident_tier0_protection" {
  count      = local.attach_policy.tier0_service_protection ? 1 : 0
  agent_name = sg_agent.sre_incident.name
  policy_id  = var.policy_ids.tier0_service_protection
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_incident_blast_radius" {
  count      = local.attach_policy.blast_radius_limit ? 1 : 0
  agent_name = sg_agent.sre_incident.name
  policy_id  = var.policy_ids.blast_radius_limit
  enabled    = true
}

# --- sre_triage ---
resource "sg_agent_policy_attachment" "sre_triage_dangerous_ops" {
  agent_name = sg_agent.sre_triage.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_triage_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate ? 1 : 0
  agent_name = sg_agent.sre_triage.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_triage_tier0_protection" {
  count      = local.attach_policy.tier0_service_protection ? 1 : 0
  agent_name = sg_agent.sre_triage.name
  policy_id  = var.policy_ids.tier0_service_protection
  enabled    = true
}

# --- sre_change_correlation ---
resource "sg_agent_policy_attachment" "sre_change_correlation_dangerous_ops" {
  agent_name = sg_agent.sre_change_correlation.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_change_correlation_data_risk" {
  count      = local.attach_policy.data_risk_pii ? 1 : 0
  agent_name = sg_agent.sre_change_correlation.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

# --- sre_auto_remediation ---
resource "sg_agent_policy_attachment" "sre_auto_remediation_dangerous_ops" {
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_prod_write_gate" {
  count      = local.attach_policy.prod_write_gate ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_tier0" {
  count      = local.attach_policy.tier0_service_protection ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.tier0_service_protection
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_blast_radius" {
  count      = local.attach_policy.blast_radius_limit ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.blast_radius_limit
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_freeze_window" {
  count      = local.attach_policy.freeze_window ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.freeze_window
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_data_risk" {
  count      = local.attach_policy.data_risk_pii ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_post_action" {
  count      = local.attach_policy.post_action_verification ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.post_action_verification
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_sre_remediation" {
  count      = local.attach_policy.sre_remediation ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

# --- sre_risk_posture ---
resource "sg_agent_policy_attachment" "sre_risk_posture_dangerous_ops" {
  agent_name = sg_agent.sre_risk_posture.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

# =============================================================================
# Runbook SOPs
# =============================================================================

resource "sg_runbook_sop" "db_failover" {
  name        = "rds-aurora-failover"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/rds-aurora-failover.md", {}))
}

resource "sg_runbook_sop" "cache_restart" {
  name        = "redis-cluster-drain-restart"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/redis-cluster-drain-restart.md", {}))
}

resource "sg_runbook_sop" "pod_crashloop_recovery" {
  name        = "pod-crashloop-recovery"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/pod-crashloop-recovery.md", {}))
}

resource "sg_runbook_sop" "ssl_cert_renewal" {
  name        = "tls-certificate-renewal"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/tls-certificate-renewal.md", {}))
}

resource "sg_runbook_sop" "dns_failover" {
  name        = "route53-dns-failover"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/route53-dns-failover.md", {}))
}

resource "sg_runbook_sop" "memory_pressure_mitigation" {
  name        = "node-memory-pressure-mitigation"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/node-memory-pressure-mitigation.md", {}))
}

resource "sg_runbook_sop" "deployment_rollback" {
  name        = "argocd-rollback"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/argocd-rollback.md", {}))
}

resource "sg_runbook_sop" "grafana_metrics_triage" {
  name        = "grafana-metrics-triage"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-metrics-triage.md", {}))
}

resource "sg_runbook_sop" "incident_communications" {
  name        = "incident-communications"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/incident-communications.md", {}))
}

# =============================================================================
# Remediation Patterns
# =============================================================================

resource "sg_remediation_pattern" "restart_pod" {
  name              = "restart-pod"
  description       = trimspace(templatefile("${path.module}/templates/remediation-restart-pod.md", {}))
  risk_level        = "low"
  blast_radius      = "single-pod"
  requires_approval = false
  approve           = true
}

resource "sg_remediation_pattern" "scale_up_hpa" {
  name              = "scale-up-hpa"
  description       = trimspace(templatefile("${path.module}/templates/remediation-scale-up-hpa.md", {}))
  risk_level        = "low"
  blast_radius      = "single-deployment"
  requires_approval = false
  approve           = true
}

resource "sg_remediation_pattern" "scale_up_asg" {
  name              = "scale-up-asg"
  description       = trimspace(templatefile("${path.module}/templates/remediation-scale-up-asg.md", {}))
  risk_level        = "medium"
  blast_radius      = "single-az"
  requires_approval = true
  approve           = true
}

resource "sg_remediation_pattern" "cordon_drain_node" {
  name              = "cordon-drain-node"
  description       = trimspace(templatefile("${path.module}/templates/remediation-cordon-drain-node.md", {}))
  risk_level        = "medium"
  blast_radius      = "single-node"
  requires_approval = true
  approve           = true
}

resource "sg_remediation_pattern" "rollback_deploy" {
  name              = "rollback-deploy"
  description       = trimspace(templatefile("${path.module}/templates/remediation-rollback-deploy.md", {}))
  risk_level        = "high"
  blast_radius      = "service-wide"
  requires_approval = true
  approve           = true
}

resource "sg_remediation_pattern" "failover_rds" {
  name              = "failover-rds"
  description       = trimspace(templatefile("${path.module}/templates/remediation-failover-rds.md", {}))
  risk_level        = "high"
  blast_radius      = "database-cluster"
  requires_approval = true
  approve           = true
}

resource "sg_remediation_pattern" "rotate_secrets" {
  name              = "rotate-secrets"
  description       = trimspace(templatefile("${path.module}/templates/remediation-rotate-secrets.md", {}))
  risk_level        = "high"
  blast_radius      = "multi-service"
  requires_approval = true
  approve           = true
}

resource "sg_remediation_pattern" "enable_circuit_breaker" {
  name              = "enable-circuit-breaker"
  description       = trimspace(templatefile("${path.module}/templates/remediation-enable-circuit-breaker.md", {}))
  risk_level        = "low"
  blast_radius      = "single-upstream"
  requires_approval = false
  approve           = true
}

# =============================================================================
# Evidence Checklists
# =============================================================================

resource "sg_evidence_checklist" "post_incident_review" {
  name        = "post-incident-review"
  description = trimspace(templatefile("${path.module}/templates/evidence-post-incident-review.md", {}))
  approve     = true
  required_items = [
    "incident_timeline_documented",
    "customer_impact_assessed",
    "active_monitoring_links_attached",
  ]
  optional_items = ["postmortem_draft_started", "pagerduty_incident_linked"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.72
  }
  metadata = { playbook = "incident-response" }
}

resource "sg_evidence_checklist" "change_validation" {
  name        = "change-validation"
  description = trimspace(templatefile("${path.module}/templates/evidence-change-validation.md", {}))
  approve     = true
  required_items = [
    "change_ticket_linked",
    "peer_review_or_approval_recorded",
    "rollback_plan_acknowledged",
  ]
  optional_items = ["canary_metrics_snapshot", "feature_flag_state_captured"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.7
  }
  metadata = { playbook = "change-management" }
}

resource "sg_evidence_checklist" "security_incident" {
  name        = "security-incident-response"
  description = trimspace(templatefile("${path.module}/templates/evidence-security-incident-response.md", {}))
  approve     = true
  required_items = [
    "ioc_or_attack_vector_documented",
    "affected_systems_inventory",
    "containment_actions_listed",
  ]
  optional_items = ["law_enforcement_ticket", "customer_notice_template"]
  scoring = {
    min_required         = 2
    confidence_threshold = 0.75
  }
  metadata = { playbook = "security-incident" }
}

resource "sg_evidence_checklist" "incident_quick_triage" {
  name        = "incident-quick-triage"
  description = "Lightweight proof-of-work for fast P3/P4 triage: confirm signals and next step before closing or escalating."
  approve     = true
  required_items = [
    "primary_alert_or_ticket_linked",
    "service_health_snapshot_captured",
  ]
  optional_items = ["recommended_owner_or_team"]
  scoring = {
    min_required         = 1
    confidence_threshold = 0.65
  }
  metadata = { playbook = "incident-triage" }
}

# =============================================================================
# Incident Response Workflow
# =============================================================================

resource "sg_workflow" "incident_response" {
  name        = local.workflow_incident_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-incident-response.md", {}))
  approve     = true

  triggers = [
    { field = "incident_title_contains", values = ["outage", "degradation", "p1", "sev1", "sev2"], type = "passive" },
    { field = "event_type", values = ["incident.triggered", "incident.escalated"], type = "active", source = "pagerduty" },
    { field = "alert_priority", values = ["P1", "P2"], type = "active", source = "datadog" },
  ]

  required_inputs = ["incident_id", "severity"]
  optional_inputs = ["service_name", "alert_url", "pagerduty_incident_id"]

  runbook_refs = [
    sg_runbook_sop.db_failover.name,
    sg_runbook_sop.pod_crashloop_recovery.name,
    sg_runbook_sop.dns_failover.name,
    sg_runbook_sop.memory_pressure_mitigation.name,
    sg_runbook_sop.deployment_rollback.name,
    sg_runbook_sop.grafana_metrics_triage.name,
    sg_runbook_sop.incident_communications.name,
  ]

  evidence_checklist_ref = sg_evidence_checklist.post_incident_review.name

  example_queries = [
    "PagerDuty fired a P1 for checkout-service — what's going on?",
    "Datadog shows 5xx spike on payment-api, need immediate triage",
    "Our cart service is timing out in us-east-1, can you investigate?",
    "Error rates jumped after the last deploy, help us roll back",
  ]

  stages = [
    { stage_id = "collect-signals", description = "Pull real-time metrics, logs, traces, and active alerts", note = "Query monitors, fetch K8s events, capture anomalies.", required = true },
    { stage_id = "correlate-changes", description = "Cross-reference anomaly timeline against recent deploys and config changes", note = "Pull ArgoCD sync history, GitHub merge events, Terraform diffs.", required = true },
    { stage_id = "assess-blast-radius", description = "Map failure impact across service dependency graph", note = "Walk service catalog, estimate affected user requests.", required = true },
    { stage_id = "determine-severity", description = "Classify incident severity and escalate accordingly", note = "Combine correlation and blast-radius data against severity matrix.", required = true },
    { stage_id = "recommend-action", description = "Propose ranked remediation actions and execute safe ones automatically", note = "Auto-execute low-risk. Queue high-risk for HITL approval.", required = true },
  ]

  stage_bindings = [
    { stage_id = "collect-signals", agent_ref = sg_agent.sre_triage.name, runbook_refs = [sg_runbook_sop.pod_crashloop_recovery.name, sg_runbook_sop.memory_pressure_mitigation.name, sg_runbook_sop.grafana_metrics_triage.name], skill_refs = concat(["sre-observability-triage", "sre-signal-dossier"], try(var.workflow_skill_refs["incident-response::collect-signals"], [])), note = "Triage agent gathers initial signal dossier." },
    { stage_id = "correlate-changes", agent_ref = sg_agent.sre_change_correlation.name, stage_depends_on = ["collect-signals"], runbook_refs = [sg_runbook_sop.deployment_rollback.name], skill_refs = concat(["sre-change-correlation", "sre-deploy-history"], try(var.workflow_skill_refs["incident-response::correlate-changes"], [])), note = "Change-correlation agent finds recent mutations." },
    { stage_id = "assess-blast-radius", agent_ref = sg_agent.sre_risk_posture.name, stage_depends_on = ["collect-signals"], skill_refs = concat(["sre-blast-radius", "sre-dependency-walk"], try(var.workflow_skill_refs["incident-response::assess-blast-radius"], [])), note = "Risk-posture agent sizes impact." },
    { stage_id = "determine-severity", agent_ref = sg_agent.sre_incident.name, stage_depends_on = ["correlate-changes", "assess-blast-radius"], runbook_refs = [sg_runbook_sop.incident_communications.name], skill_refs = concat(["sre-severity-matrix", "sre-incident-comms"], try(var.workflow_skill_refs["incident-response::determine-severity"], [])), note = "Incident commander classifies severity." },
    { stage_id = "recommend-action", agent_ref = sg_agent.sre_auto_remediation.name, stage_depends_on = ["determine-severity"], runbook_refs = [sg_runbook_sop.db_failover.name, sg_runbook_sop.dns_failover.name, sg_runbook_sop.deployment_rollback.name], skill_refs = concat(["sre-safe-remediation", "sre-rollback-playbook"], try(var.workflow_skill_refs["incident-response::recommend-action"], [])), note = "Auto-remediation agent executes safe fixes." },
  ]
}

resource "sg_workflow" "incident_quick_triage" {
  name        = local.workflow_incident_quick_name
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-incident-triage.md", {}))
  approve     = true

  triggers = [
    { field = "incident_title_contains", values = ["warning", "degradation", "p3", "p4", "sev3", "sev4"], type = "passive" },
  ]

  required_inputs        = ["incident_id", "severity"]
  optional_inputs        = ["service_name", "alert_url"]
  evidence_checklist_ref = sg_evidence_checklist.incident_quick_triage.name

  runbook_refs = [
    sg_runbook_sop.pod_crashloop_recovery.name,
    sg_runbook_sop.deployment_rollback.name,
  ]

  example_queries = [
    "Got a P3 alert on the search index service, can you take a quick look?",
    "Pod restarts spiking on the recommendations service",
    "Cache hit ratio dropped on session-store, might need a restart",
  ]

  stages = [
    { stage_id = "collect-signals", description = "Rapid diagnostic sweep for the affected service", note = "Focus on the impacted service namespace only.", required = true },
    { stage_id = "recommend-action", description = "Propose a targeted fix or escalate to full incident-response", note = "Auto-execute safe fixes. Escalate broader impact.", required = true },
  ]

  stage_bindings = [
    { stage_id = "collect-signals", agent_ref = sg_agent.sre_triage.name, runbook_refs = [sg_runbook_sop.pod_crashloop_recovery.name], skill_refs = concat(["sre-quick-signal-scan"], try(var.workflow_skill_refs["incident-triage::collect-signals"], [])), note = "Focused diagnostic pass." },
    { stage_id = "recommend-action", agent_ref = sg_agent.sre_auto_remediation.name, stage_depends_on = ["collect-signals"], runbook_refs = [sg_runbook_sop.deployment_rollback.name], skill_refs = concat(["sre-targeted-remediation"], try(var.workflow_skill_refs["incident-triage::recommend-action"], [])), note = "Recommend and execute safe fixes." },
  ]
}
