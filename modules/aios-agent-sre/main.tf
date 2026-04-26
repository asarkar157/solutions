terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.0" }
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
  count      = var.policy_ids.sre_remediation != "" ? 1 : 0
  agent_name = sg_agent.sre_incident.name
  policy_id  = var.policy_ids.sre_remediation
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_incident_prod_write_gate" {
  count      = var.policy_ids.prod_write_gate != "" ? 1 : 0
  agent_name = sg_agent.sre_incident.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_incident_tier0_protection" {
  count      = var.policy_ids.tier0_service_protection != "" ? 1 : 0
  agent_name = sg_agent.sre_incident.name
  policy_id  = var.policy_ids.tier0_service_protection
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_incident_blast_radius" {
  count      = var.policy_ids.blast_radius_limit != "" ? 1 : 0
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
  count      = var.policy_ids.prod_write_gate != "" ? 1 : 0
  agent_name = sg_agent.sre_triage.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_triage_tier0_protection" {
  count      = var.policy_ids.tier0_service_protection != "" ? 1 : 0
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
  count      = var.policy_ids.data_risk_pii != "" ? 1 : 0
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
  count      = var.policy_ids.prod_write_gate != "" ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.prod_write_gate
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_tier0" {
  count      = var.policy_ids.tier0_service_protection != "" ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.tier0_service_protection
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_blast_radius" {
  count      = var.policy_ids.blast_radius_limit != "" ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.blast_radius_limit
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_freeze_window" {
  count      = var.policy_ids.freeze_window != "" ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.freeze_window
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_data_risk" {
  count      = var.policy_ids.data_risk_pii != "" ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_post_action" {
  count      = var.policy_ids.post_action_verification != "" ? 1 : 0
  agent_name = sg_agent.sre_auto_remediation.name
  policy_id  = var.policy_ids.post_action_verification
  enabled    = true
}

resource "sg_agent_policy_attachment" "sre_auto_remediation_sre_remediation" {
  count      = var.policy_ids.sre_remediation != "" ? 1 : 0
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
  description = "Promote Aurora read-replica to primary in us-west-2. Steps: 1) Verify replica lag < 5 s via CloudWatch ReplicaLag metric, 2) Enable DNS failover in Route 53 health check, 3) Issue `aws rds failover-db-cluster --db-cluster-identifier checkout-prod`, 4) Validate write path within 30 s, 5) Notify #incident Slack channel with failover timestamp and new writer endpoint."
}

resource "sg_runbook_sop" "cache_restart" {
  name        = "redis-cluster-drain-restart"
  description = "Gracefully drain and restart ElastiCache Redis cluster nodes. Steps: 1) Set cluster to maintenance mode, 2) Enable AOF persistence, 3) Drain connections from target node, 4) Wait for active connection count to reach 0, 5) Restart node, 6) Re-add to target group, 7) Validate cache hit ratio returns above 90% within 5 min."
}

resource "sg_runbook_sop" "pod_crashloop_recovery" {
  name        = "pod-crashloop-recovery"
  description = "Recover a CrashLoopBackOff pod without service disruption. Steps: 1) `kubectl describe pod` to capture exit code, 2) `kubectl logs --previous` to extract root cause, 3) If OOMKilled, check memory limits vs usage, 4) If config error, verify ConfigMap/Secret mounts, 5) Apply fix, 6) Monitor pod restart count for 10 min."
}

resource "sg_runbook_sop" "ssl_cert_renewal" {
  name        = "tls-certificate-renewal"
  description = "Emergency TLS certificate renewal for ALB and Kubernetes ingress. Steps: 1) Check certificate expiry with `aws acm describe-certificate`, 2) Trigger re-validation, 3) Verify new cert serial via `openssl s_client`, 4) Validate no mixed-content warnings, 5) Update monitoring alert threshold."
}

resource "sg_runbook_sop" "dns_failover" {
  name        = "route53-dns-failover"
  description = "Activate Route 53 DNS failover to secondary region. Steps: 1) Confirm primary region health check is failing, 2) Verify secondary region is healthy, 3) Update failover record set, 4) Set TTL to 60 s during incident, 5) Monitor DNS resolution, 6) Restore original TTL after recovery."
}

resource "sg_runbook_sop" "memory_pressure_mitigation" {
  name        = "node-memory-pressure-mitigation"
  description = "Respond to Kubernetes MemoryPressure node condition. Steps: 1) Identify affected node, 2) List top memory consumers, 3) Evict non-critical pods, 4) Cordon node, 5) Capture heap dump if leak suspected, 6) Terminate instance for ASG replacement if hardware fault, 7) Uncordon after new node Ready."
}

resource "sg_runbook_sop" "deployment_rollback" {
  name        = "argocd-rollback"
  description = "Roll back a failing ArgoCD deployment to last known good revision. Steps: 1) Identify last healthy sync revision, 2) Trigger rollback, 3) Monitor rollout status, 4) Validate error rate drops below SLO threshold, 5) Notify #releases channel, 6) Create post-mortem ticket if regression escaped staging."
}

resource "sg_runbook_sop" "grafana_metrics_triage" {
  name        = "grafana-metrics-triage"
  description = "Triage an incident by polling real-time metrics from Grafana. Steps: 1) Query grafana_search_dashboards for the affected service. 2) Use grafana_get_dashboard_data for the last 30 minutes. 3) Summarize findings to enrich the incident context."
}

resource "sg_runbook_sop" "incident_communications" {
  name        = "incident-communications"
  description = "Standard operating procedure for incident escalation and tracking. Steps: 1) Post initial SITREP to #incident-war-room Slack channel. 2) Create a tracking ticket in Linear. 3) Provide the ticket ID in the Slack thread."
}

# =============================================================================
# Remediation Patterns
# =============================================================================

resource "sg_remediation_pattern" "restart_pod" {
  name              = "restart-pod"
  description       = "Delete and let the ReplicaSet recreate a single misbehaving pod. Safe for stateless workloads behind a load balancer with >= 2 ready replicas."
  version           = 1
  risk_level        = "low"
  blast_radius      = "single-pod"
  requires_approval = false
}

resource "sg_remediation_pattern" "scale_up_hpa" {
  name              = "scale-up-hpa"
  description       = "Temporarily raise HPA maxReplicas and targetCPUUtilization to absorb a traffic spike. Revert after 30 min if load normalises."
  version           = 1
  risk_level        = "low"
  blast_radius      = "single-deployment"
  requires_approval = false
}

resource "sg_remediation_pattern" "scale_up_asg" {
  name              = "scale-up-asg"
  description       = "Increase EC2 ASG desired capacity by 2 instances. Validates new instances pass ELB health checks within 5 min. Scales back 1 hour after error rate returns to baseline."
  version           = 1
  risk_level        = "medium"
  blast_radius      = "single-az"
  requires_approval = true
}

resource "sg_remediation_pattern" "cordon_drain_node" {
  name              = "cordon-drain-node"
  description       = "Cordon a degraded Kubernetes node and gracefully drain existing workloads with PDB-aware eviction."
  version           = 1
  risk_level        = "medium"
  blast_radius      = "single-node"
  requires_approval = true
}

resource "sg_remediation_pattern" "rollback_deploy" {
  name              = "rollback-deploy"
  description       = "Revert the most recent ArgoCD or Helm deployment to the previous known-good revision."
  version           = 1
  risk_level        = "high"
  blast_radius      = "service-wide"
  requires_approval = true
}

resource "sg_remediation_pattern" "failover_rds" {
  name              = "failover-rds"
  description       = "Promote an RDS Aurora read-replica to primary writer. Causes 15-30 s of write unavailability during DNS propagation."
  version           = 1
  risk_level        = "high"
  blast_radius      = "database-cluster"
  requires_approval = true
}

resource "sg_remediation_pattern" "rotate_secrets" {
  name              = "rotate-secrets"
  description       = "Rotate a compromised or expired API key/credential. Generate new credential, update Vault, trigger rolling restart, revoke old credential."
  version           = 1
  risk_level        = "high"
  blast_radius      = "multi-service"
  requires_approval = true
}

resource "sg_remediation_pattern" "enable_circuit_breaker" {
  name              = "enable-circuit-breaker"
  description       = "Activate Istio/Envoy circuit breaker on a failing upstream dependency to shed load and prevent cascade failures."
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
  description = "Sev-1/Sev-2 post-incident review evidence: timeline, root cause analysis, affected services, dashboard screenshots, remediations applied, action items, and lessons learned."
}

resource "sg_evidence_checklist" "change_validation" {
  name        = "change-validation"
  description = "Production change validation evidence: pre-change SLI baseline, deployment diff, canary metrics comparison, smoke test results, rollback plan confirmation, and post-change SLI snapshot."
}

resource "sg_evidence_checklist" "security_incident" {
  name        = "security-incident-response"
  description = "Security incident response evidence: detection source, affected resources inventory, blast radius assessment, containment actions, forensic artifacts, credential rotation confirmation, and regulatory notification checklist."
}

# =============================================================================
# Incident Response Workflow
# =============================================================================

resource "sg_workflow" "incident_response" {
  name        = "incident-response"
  domain      = "incident-response"
  description = "End-to-end production incident response: triages alerts, correlates with recent changes, evaluates blast radius, classifies severity, and recommends or auto-executes remediation — with human-in-the-loop approval for high-risk actions."

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
  description = "Fast-track triage for Sev-3/Sev-4 alerts: collects key metrics, identifies probable root cause, and recommends a fix."

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
