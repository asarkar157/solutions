output "app_name" {
  description = "Catalog slug of the bound SRE app install."
  value       = sg_app.sre.app_name
}

output "configured" {
  description = "True when the app is installed and configured for the current org."
  value       = sg_app.sre.configured
}

output "integration_names" {
  description = "Integration names currently bound to the SRE app install."
  value       = sg_app.sre.integrations
}

output "existing_app_integration_names" {
  description = "Integration names read from data.sg_app before merge (empty when merge_existing_app_integrations is false)."
  value       = local.existing_app_integration_names
}

output "added_integration_names" {
  description = "Integration names passed in integration_names (before merge)."
  value       = compact(var.integration_names)
}

output "display_name" {
  description = "Human-readable application name from the catalog."
  value       = sg_app.sre.display_name
}

output "installation_id" {
  description = "Server-assigned installation UUID."
  value       = sg_app.sre.id
}

output "discovery_bootstrap_enabled" {
  description = "True when workspace setup_type config is set for post-bind onboarding (run discovery from the SRE app UI)."
  value       = var.enable_discovery_bootstrap
}

output "alert_webhook_trigger_urls" {
  description = "Map of alert webhook key (source:integration) to absolute Guild trigger URL for monitor webhooks."
  value = {
    for k, wh in sg_sre_alert_webhook.this : k => wh.trigger_url
  }
  sensitive = true
}

output "alert_webhook_ids" {
  description = "Map of alert webhook key (source:integration) to Guild webhook UUID."
  value = {
    for k, wh in sg_sre_alert_webhook.this : k => wh.guild_webhook_id
  }
}

output "investigator_remote_runners" {
  description = "Remote runners on the investigator after merge (empty when remote_runner_name is unset)."
  value       = local.attach_remote_runner ? tolist(sg_agent.investigator[0].remote_runners) : []
}

output "investigator_policies_attached" {
  description = "Policy keys attached to investigator_agent_name via sg_agent_policy_attachment."
  value       = sort(keys(sg_agent_policy_attachment.investigator))
}
