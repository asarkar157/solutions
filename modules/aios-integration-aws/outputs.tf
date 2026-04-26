output "integration_name" {
  description = "Registered name of the AWS integration"
  value       = sg_guild_integration.aws.name
}

output "integration_id" {
  description = "ID of the AWS integration"
  value       = sg_guild_integration.aws.id
}

output "secret_id" {
  description = "ID of the AWS vault secret"
  value       = sg_secret.aws_vault.id
}

output "secret_name" {
  description = "Name of the AWS vault secret"
  value       = sg_secret.aws_vault.name
}
