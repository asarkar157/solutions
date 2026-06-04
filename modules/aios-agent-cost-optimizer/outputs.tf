output "agent_name" { value = sg_agent.cost_optimizer.name }

output "workflow_name" {
  description = "Name of the finops-review workflow. Pass to aios-agent-schedules with target_type = \"workflow\" for periodic FinOps reports."
  value       = sg_workflow.finops_review.name
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = nonsensitive(local.resolved_aws_integration_name)
}

output "azure_integration_name" {
  description = "Resolved Azure Guild integration name."
  value       = nonsensitive(local.resolved_azure_integration_name)
}

output "gcp_integration_name" {
  description = "Resolved GCP Guild integration name."
  value       = nonsensitive(local.resolved_gcp_integration_name)
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = nonsensitive(local.resolved_slack_integration_name)
}
