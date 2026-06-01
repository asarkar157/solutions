output "integration_name" {
  value = sg_guild_integration.gitlab.name
}

output "secret_id" {
  value = local.secret_id
}
