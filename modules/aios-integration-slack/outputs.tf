output "integration_name" {
  value = sg_guild_integration.slack.name
}

output "integration_id" {
  value = sg_guild_integration.slack.id
}

output "secret_id" {
  description = "ID of the `sg_secret` bound to the Slack integration. Equals `var.existing_secret_id` when supplied, otherwise the newly-created secret's ID."
  value       = local.secret_id
  sensitive   = true
}
