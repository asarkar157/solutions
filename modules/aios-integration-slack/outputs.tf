output "integration_name" {
  value = sg_guild_integration.slack.name
}

output "integration_id" {
  value = sg_guild_integration.slack.id
}

output "secret_id" {
  value = sg_secret.slack_vault.id
}
