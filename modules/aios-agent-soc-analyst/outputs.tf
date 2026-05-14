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

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = local.resolved_aws_integration_name
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = local.resolved_github_integration_name
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = local.resolved_slack_integration_name
}

output "splunk_integration_name" {
  description = "Splunk Guild integration name (passthrough from var.existing_splunk_integration_name)."
  value       = local.resolved_splunk_integration_name
}
