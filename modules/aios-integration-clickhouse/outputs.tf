output "integration_name" {
  value = sg_guild_integration.clickhouse.name
}

output "integration_id" {
  value = sg_guild_integration.clickhouse.id
}

output "secret_id" {
  description = "ID of the `sg_secret` bound to this integration (newly provisioned or pre-existing)."
  value       = local.secret_id
  sensitive   = true
}
