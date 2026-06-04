output "agent_name" { value = sg_agent.workspace_assistant.name }

output "workflow_name" {
  description = "Name of the developer-daily-triage workflow."
  value       = sg_workflow.developer_daily_triage.name
}

output "google_integration_name" {
  description = "Google Workspace Guild integration name (passthrough)."
  value       = nonsensitive(local.resolved_google_integration_name)
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = nonsensitive(local.resolved_slack_integration_name)
}

output "linear_integration_name" {
  description = "Resolved Linear Guild integration name."
  value       = nonsensitive(local.resolved_linear_integration_name)
}
