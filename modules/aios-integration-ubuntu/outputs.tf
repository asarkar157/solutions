output "integration_id" { value = sg_guild_integration.ubuntu_cli.id }
output "integration_name" { value = nonsensitive(sg_guild_integration.ubuntu_cli.name) }
