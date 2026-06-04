output "agent_name" { value = sg_agent.azure_devops_sre.name }

output "workflow_name" {
  description = "Name of the azure-devops-full-triage workflow."
  value       = sg_workflow.azure_devops_full_triage.name
}

output "azure_integration_name" {
  description = "Resolved Azure Guild integration name."
  value       = nonsensitive(local.resolved_azure_integration_name)
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = nonsensitive(local.resolved_slack_integration_name)
}
