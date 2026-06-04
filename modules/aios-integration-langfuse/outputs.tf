output "integration_name" {
  description = "Registered name of the Langfuse integration"
  value       = nonsensitive(sg_guild_integration.langfuse.name)
}

output "integration_id" {
  description = "Server-assigned Guild integration ID for the Langfuse integration"
  value       = sg_guild_integration.langfuse.id
}

output "secret_id" {
  description = "Vault secret ID holding Langfuse API credentials"
  value       = sg_secret.langfuse_vault.id
}
