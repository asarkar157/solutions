output "integration_name" {
  description = "Name of the Jira Guild integration."
  value       = nonsensitive(sg_guild_integration.jira.name)
}

output "secret_id" {
  description = "Vault secret ID bound to the Jira integration."
  sensitive   = true
  value       = local.secret_id
}

output "atlassian_site_name" {
  description = "Jira Cloud site name projected onto ATLASSIAN_SITE_NAME for the sidecar (derived from base_url unless overridden)."
  value       = local.site_name
}

output "sidecar_env_keys" {
  description = "Names of the environment variables the module sets on the Jira sidecar (values omitted)."
  value       = sort(keys(local.effective_env))
}
