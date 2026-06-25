output "integration_id" {
  description = "The ID of the provisioned Jenkins integration."
  value       = sg_guild_integration.jenkins.id
}

output "integration_name" {
  description = "The name of the provisioned Jenkins integration."
  value       = nonsensitive(sg_guild_integration.jenkins.name)
}

output "secret_id" {
  description = "ID of the `sg_secret` bound to the Jenkins integration."
  value       = local.secret_id
  sensitive   = true
}
