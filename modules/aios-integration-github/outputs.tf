output "integration_name" {
  value = sg_guild_integration.github.name
}

output "integration_id" {
  value = sg_guild_integration.github.id
}

output "secret_id" {
  value = sg_secret.github_vault.id
}
