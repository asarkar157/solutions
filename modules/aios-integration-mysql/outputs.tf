output "integration_name" {
  value = nonsensitive(sg_guild_integration.mysql.name)
}

output "integration_id" {
  value = sg_guild_integration.mysql.id
}

output "secret_id" {
  description = "ID of the `sg_secret` bound to this integration."
  value       = local.secret_id
  sensitive   = true
}
