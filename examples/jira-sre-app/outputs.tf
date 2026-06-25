output "jira_integration_name" {
  description = "Name of the Jira Guild integration created by this root."
  value       = module.jira_integration.integration_name
}

output "sre_app_integration_names" {
  description = "Integration names bound to the SRE app install after apply (empty when bind_to_sre_app is false)."
  value       = var.bind_to_sre_app ? module.sre_app_bindings[0].integration_names : []
}

output "sre_app_configured" {
  description = "Whether the SRE app install is configured (null when bind_to_sre_app is false)."
  value       = var.bind_to_sre_app ? module.sre_app_bindings[0].configured : null
}
