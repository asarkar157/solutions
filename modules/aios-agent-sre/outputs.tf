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
