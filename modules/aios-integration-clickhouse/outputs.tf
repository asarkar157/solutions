output "integration_name" {
  value = sg_guild_integration.clickhouse.name
}

output "integration_id" {
  value = sg_guild_integration.clickhouse.id
}

output "secret_id" {
  value = sg_secret.clickhouse_vault.id
}
