terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.8, < 0.2.0" }
  }
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
  name        = "alert-triage-analyst"
  persona     = file("${path.module}/personas/sre-triage.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]

  integrations = compact([
    lookup(var.integration_names, "grafana", "") != "" ? var.integration_names.grafana : null,
  ])
}

resource "sg_agent" "sre_change_correlation" {
  name        = "change-correlation-analyst"
  persona     = file("${path.module}/personas/sre-change-correlation.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]
}

resource "sg_agent" "sre_auto_remediation" {
  name        = "auto-remediation-engineer"
  persona     = file("${path.module}/personas/sre-auto-remediation.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]

  hitl = {
    always_allowed = ["run_shell"]
  }

  integrations = []
}

resource "sg_agent" "sre_risk_posture" {
  name        = "risk-posture-assessor"
  persona     = file("${path.module}/personas/sre-risk-posture.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gemini_flash]
}

resource "sg_agent" "sre_incident" {
  name        = "incident-commander"
  persona     = file("${path.module}/personas/sre-incident.md")
  model_names = [var.model_names.gpt4o, var.model_names.claude_sonnet]

  integrations = compact([
    lookup(var.integration_names, "grafana", "") != "" ? var.integration_names.grafana : null,
    lookup(var.integration_names, "slack", "") != "" ? var.integration_names.slack : null,
    lookup(var.integration_names, "linear", "") != "" ? var.integration_names.linear : null,
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
  # Optional attachments: create only when the policies module supplied a non-empty ID and the flag allows it.
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
  description = trimspace(templatefile("${path.module}/templates/rds-aurora-failover.md", {}))
}

resource "sg_runbook_sop" "cache_restart" {
  name        = "redis-cluster-drain-restart"
  description = trimspace(templatefile("${path.module}/templates/redis-cluster-drain-restart.md", {}))
}

resource "sg_runbook_sop" "pod_crashloop_recovery" {
  name        = "pod-crashloop-recovery"
  description = trimspace(templatefile("${path.module}/templates/pod-crashloop-recovery.md", {}))
}

resource "sg_runbook_sop" "ssl_cert_renewal" {
  name        = "tls-certificate-renewal"
  description = trimspace(templatefile("${path.module}/templates/tls-certificate-renewal.md", {}))
}

resource "sg_runbook_sop" "dns_failover" {
  name        = "route53-dns-failover"
  description = trimspace(templatefile("${path.module}/templates/route53-dns-failover.md", {}))
}

resource "sg_runbook_sop" "memory_pressure_mitigation" {
  name        = "node-memory-pressure-mitigation"
  description = trimspace(templatefile("${path.module}/templates/node-memory-pressure-mitigation.md", {}))
}

resource "sg_runbook_sop" "deployment_rollback" {
  name        = "argocd-rollback"
  description = trimspace(templatefile("${path.module}/templates/argocd-rollback.md", {}))
}

resource "sg_runbook_sop" "grafana_metrics_triage" {
  name        = "grafana-metrics-triage"
  description = trimspace(templatefile("${path.module}/templates/grafana-metrics-triage.md", {}))
}

resource "sg_runbook_sop" "incident_communications" {
  name        = "incident-communications"
  description = trimspace(templatefile("${path.module}/templates/incident-communications.md", {}))
}

# =============================================================================
# Remediation Patterns
# =============================================================================

resource "sg_remediation_pattern" "restart_pod" {
  name              = "restart-pod"
  description       = trimspace(templatefile("${path.module}/templates/remediation-restart-pod.md", {}))
  version           = 1
  risk_level        = "low"
  blast_radius      = "single-pod"
  requires_approval = false
}

resource "sg_remediation_pattern" "scale_up_hpa" {
  name              = "scale-up-hpa"
  description       = trimspace(templatefile("${path.module}/templates/remediation-scale-up-hpa.md", {}))
  version           = 1
  risk_level        = "low"
  blast_radius      = "single-deployment"
  requires_approval = false
}

resource "sg_remediation_pattern" "scale_up_asg" {
  name              = "scale-up-asg"
  description       = trimspace(templatefile("${path.module}/templates/remediation-scale-up-asg.md", {}))
  version           = 1
  risk_level        = "medium"
  blast_radius      = "single-az"
  requires_approval = true
}

resource "sg_remediation_pattern" "cordon_drain_node" {
  name              = "cordon-drain-node"
  description       = trimspace(templatefile("${path.module}/templates/remediation-cordon-drain-node.md", {}))
  version           = 1
  risk_level        = "medium"
  blast_radius      = "single-node"
  requires_approval = true
}

resource "sg_remediation_pattern" "rollback_deploy" {
  name              = "rollback-deploy"
  description       = trimspace(templatefile("${path.module}/templates/remediation-rollback-deploy.md", {}))
  version           = 1
  risk_level        = "high"
  blast_radius      = "service-wide"
  requires_approval = true
}

resource "sg_remediation_pattern" "failover_rds" {
  name              = "failover-rds"
  description       = trimspace(templatefile("${path.module}/templates/remediation-failover-rds.md", {}))
  version           = 1
  risk_level        = "high"
  blast_radius      = "database-cluster"
  requires_approval = true
}

resource "sg_remediation_pattern" "rotate_secrets" {
  name              = "rotate-secrets"
  description       = trimspace(templatefile("${path.module}/templates/remediation-rotate-secrets.md", {}))
  version           = 1
  risk_level        = "high"
  blast_radius      = "multi-service"
  requires_approval = true
}

resource "sg_remediation_pattern" "enable_circuit_breaker" {
  name              = "enable-circuit-breaker"
  description       = trimspace(templatefile("${path.module}/templates/remediation-enable-circuit-breaker.md", {}))
  version           = 1
  risk_level        = "low"
  blast_radius      = "single-upstream"
  requires_approval = false
}

# =============================================================================
# Evidence Checklists
# =============================================================================

resource "sg_evidence_checklist" "post_incident_review" {
  name        = "post-incident-review"
  description = trimspace(templatefile("${path.module}/templates/evidence-post-incident-review.md", {}))
}

resource "sg_evidence_checklist" "change_validation" {
  name        = "change-validation"
  description = trimspace(templatefile("${path.module}/templates/evidence-change-validation.md", {}))
}

resource "sg_evidence_checklist" "security_incident" {
  name        = "security-incident-response"
  description = trimspace(templatefile("${path.module}/templates/evidence-security-incident-response.md", {}))
}

# =============================================================================
# Incident Response Workflow
# =============================================================================

resource "sg_workflow" "incident_response" {
  name        = "incident-response"
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
    { stage_id = "collect-signals", agent_ref = sg_agent.sre_triage.name, runbook_refs = [sg_runbook_sop.pod_crashloop_recovery.name, sg_runbook_sop.memory_pressure_mitigation.name, sg_runbook_sop.grafana_metrics_triage.name], note = "Triage agent gathers initial signal dossier." },
    { stage_id = "correlate-changes", agent_ref = sg_agent.sre_change_correlation.name, stage_depends_on = ["collect-signals"], runbook_refs = [sg_runbook_sop.deployment_rollback.name], note = "Change-correlation agent finds recent mutations." },
    { stage_id = "assess-blast-radius", agent_ref = sg_agent.sre_risk_posture.name, stage_depends_on = ["collect-signals"], note = "Risk-posture agent sizes impact." },
    { stage_id = "determine-severity", agent_ref = sg_agent.sre_incident.name, stage_depends_on = ["correlate-changes", "assess-blast-radius"], runbook_refs = [sg_runbook_sop.incident_communications.name], note = "Incident commander classifies severity." },
    { stage_id = "recommend-action", agent_ref = sg_agent.sre_auto_remediation.name, stage_depends_on = ["determine-severity"], runbook_refs = [sg_runbook_sop.db_failover.name, sg_runbook_sop.dns_failover.name, sg_runbook_sop.deployment_rollback.name], note = "Auto-remediation agent executes safe fixes." },
  ]
}

resource "sg_workflow" "incident_quick_triage" {
  name        = "incident-triage"
  domain      = "incident-response"
  description = trimspace(templatefile("${path.module}/templates/workflow-incident-triage.md", {}))
  approve     = true

  triggers = [
    { field = "incident_title_contains", values = ["warning", "degradation", "p3", "p4", "sev3", "sev4"], type = "passive" },
  ]

  required_inputs = ["incident_id", "severity"]
  optional_inputs = ["service_name", "alert_url"]

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
    { stage_id = "collect-signals", agent_ref = sg_agent.sre_triage.name, runbook_refs = [sg_runbook_sop.pod_crashloop_recovery.name], note = "Focused diagnostic pass." },
    { stage_id = "recommend-action", agent_ref = sg_agent.sre_auto_remediation.name, stage_depends_on = ["collect-signals"], runbook_refs = [sg_runbook_sop.deployment_rollback.name], note = "Recommend and execute safe fixes." },
  ]
}
