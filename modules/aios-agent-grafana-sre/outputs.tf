output "agent_name" { value = sg_agent.grafana_sre.name }

output "grafana_integration_name" {
  description = "Name of the Grafana Guild integration the agent uses."
  value       = nonsensitive(local.resolved_grafana_integration_name)
}

output "integration_name" {
  description = "Deprecated alias for `grafana_integration_name` — kept for backward compatibility."
  value       = nonsensitive(local.resolved_grafana_integration_name)
}
