output "agent_names" {
  value = {
    sre_triage             = sg_agent.sre_triage.name
    sre_change_correlation = sg_agent.sre_change_correlation.name
    sre_auto_remediation   = sg_agent.sre_auto_remediation.name
    sre_risk_posture       = sg_agent.sre_risk_posture.name
    sre_incident           = sg_agent.sre_incident.name
  }
}

output "workflow_names" {
  value = {
    incident_response     = sg_workflow.incident_response.name
    incident_quick_triage = sg_workflow.incident_quick_triage.name
  }
}

output "evidence_checklist_names" {
  description = "Stable Guild evidence checklist names for cross-module workflow wiring (e.g. SDLC release_pipeline)."
  value = {
    post_incident_review  = sg_evidence_checklist.post_incident_review.name
    change_validation     = sg_evidence_checklist.change_validation.name
    security_incident     = sg_evidence_checklist.security_incident.name
    incident_quick_triage = sg_evidence_checklist.incident_quick_triage.name
  }
}

output "grafana_integration_name" {
  description = "Resolved Grafana Guild integration name (provisioned internally, shared via override, or empty if not wired)."
  value       = local.resolved_grafana_integration_name
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = local.resolved_slack_integration_name
}

output "linear_integration_name" {
  description = "Resolved Linear Guild integration name."
  value       = local.resolved_linear_integration_name
}
