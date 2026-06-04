output "integration_name" {
  value = nonsensitive(sg_guild_integration.datadog.name)
}

output "secret_id" {
  sensitive   = true
  description = "Vault secret ID bound to the integration (empty when using only `existing_secret_id` without module-created secret)."
  value       = local.secret_id
}
