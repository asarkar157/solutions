output "integration_name" {
  value = nonsensitive(sg_guild_integration.internal_tool.name)
}

output "secret_id" {
  sensitive = true
  value     = local.secret_id
}
