output "integration_names" {
  description = "Guild integration names for scripts/test-integrations.sh"
  value       = local.integration_names
}

output "guild_test_base_url" {
  description = "Base URL for POST .../integrations/{name}/test"
  value       = "${trimsuffix(var.stackgen_url, "/")}/guild/api/v1/integrations"
}
