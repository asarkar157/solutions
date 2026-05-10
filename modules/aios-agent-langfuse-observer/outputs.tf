output "agent_name" {
  description = "Name of the Langfuse observer agent"
  value       = sg_agent.langfuse_observer.name
}

output "workflow_name" {
  description = "Name of the AI Ops Health Scorecard workflow"
  value       = sg_workflow.ai_ops_health_scorecard.name
}

output "observer_integration_names" {
  description = "Guild integration names attached to the agent (langfuse first, then other keys in sorted order). Use to verify multi-integration wiring."
  value       = local.observer_integrations
}
