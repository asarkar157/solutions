output "integration_name" {
  description = "Registered name of the Grafana integration"
  value       = sg_guild_integration.grafana.name
}

output "integration_id" {
  value = sg_guild_integration.grafana.id
}

output "secret_id" {
  value = sg_secret.grafana_vault.id
}
