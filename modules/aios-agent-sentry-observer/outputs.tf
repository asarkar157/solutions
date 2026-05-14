output "agent_name" {
  description = "Sentry observer agent name."
  value       = sg_agent.sentry_observer.name
}

output "sentry_integration_name" {
  description = "Sentry Guild integration name (passthrough)."
  value       = local.resolved_sentry_integration_name
}
