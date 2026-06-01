output "integration_name" {
  value = sg_guild_integration.argocd.name
}

output "secret_id" {
  value = local.secret_id
}
