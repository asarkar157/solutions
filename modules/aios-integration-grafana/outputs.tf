output "integration_name" {
  description = "Registered name of the Grafana integration"
  value       = sg_guild_integration.grafana.name
}

output "integration_id" {
  value = sg_guild_integration.grafana.id
}

output "secret_id" {
  description = "ID of the `sg_secret` bound to the Grafana integration."
  value       = local.secret_id
  sensitive   = true
}
