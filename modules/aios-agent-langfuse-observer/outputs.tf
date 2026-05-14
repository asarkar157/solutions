output "agent_name" {
  description = "Name of the Langfuse observer agent"
  value       = sg_agent.langfuse_observer.name
}

output "workflow_name" {
  description = "Name of the AI Ops Health Scorecard workflow"
  value       = sg_workflow.ai_ops_health_scorecard.name
}

output "observer_integration_names" {
  description = "Guild integration names attached to the agent (langfuse first, then resolved extras). Use to verify multi-integration wiring."
  value       = local.observer_integrations
}

output "langfuse_integration_name" {
  description = "Resolved Langfuse Guild integration name (passthrough)."
  value       = local.resolved_langfuse_integration_name
}

output "grafana_integration_name" {
  description = "Resolved Grafana Guild integration name."
  value       = local.resolved_grafana_integration_name
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = local.resolved_slack_integration_name
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = local.resolved_github_integration_name
}
