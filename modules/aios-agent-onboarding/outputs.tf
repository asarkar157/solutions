output "agent_name" { value = sg_agent.onboarding_assistant.name }

output "workflow_name" {
  description = "Name of the developer-onboarding workflow."
  value       = sg_workflow.developer_onboarding.name
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = nonsensitive(local.resolved_slack_integration_name)
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "linear_integration_name" {
  description = "Resolved Linear Guild integration name."
  value       = nonsensitive(local.resolved_linear_integration_name)
}

output "google_integration_name" {
  description = "Google Workspace Guild integration name (passthrough)."
  value       = nonsensitive(local.resolved_google_integration_name)
}
