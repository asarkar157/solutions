output "integration_name" {
  value = nonsensitive(sg_guild_integration.oracle.name)
}

output "integration_id" {
  value = sg_guild_integration.oracle.id
}

output "secret_id" {
  value     = local.secret_id
  sensitive = true
}
