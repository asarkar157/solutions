output "integration_id" {
  description = "ID of the Chrome browser integration."
  value       = sg_guild_integration.chrome.id
}

output "integration_name" {
  description = "Registered name of the Chrome browser integration."
  value       = nonsensitive(sg_guild_integration.chrome.name)
}
