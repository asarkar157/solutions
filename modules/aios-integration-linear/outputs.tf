output "integration_id" { value = sg_guild_integration.linear.id }
output "integration_name" { value = nonsensitive(sg_guild_integration.linear.name) }
