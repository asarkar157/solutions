output "integration_name" {
  value = sg_guild_integration.azure.name
}

output "integration_id" {
  value = sg_guild_integration.azure.id
}

output "secret_id" {
  value = sg_secret.azure_vault.id
}

output "reader_principal_id" {
  description = "Object ID of the reader service principal for role assignments"
  value       = azuread_service_principal.guild_azure_reader.object_id
}

output "azure_role_scope" {
  description = "Scope used for role assignments"
  value       = local.azure_role_scope
}

output "client_id" {
  value = local.azure_reader_client_id
}
