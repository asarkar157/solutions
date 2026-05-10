output "agent_name" {
  description = "The name of the SOC Analyst Agent"
  value       = sg_agent.soc_analyst.name
}

output "workflow_triage_name" {
  description = "The name of the Alert Triage workflow"
  value       = sg_workflow.soc_alert_triage.name
}

output "workflow_threat_hunt_name" {
  description = "The name of the Threat Hunting workflow"
  value       = sg_workflow.soc_threat_hunt.name
}
