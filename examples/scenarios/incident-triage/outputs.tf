output "next_steps" {
  description = "Copy-paste prompt to open Guild and start the demo."
  value       = <<-EOT

    Demo ready. Next steps:
      1. Open Guild:                ${var.stackgen_url}
      2. Alert-triage coordinator:  alert-triage-coordinator
      3. SRE agents available:      ${jsonencode(module.sre_agents.agent_names)}
      4. Try in chat:               "A Grafana alert just fired: ServiceUnavailable on payments-api. Triage and route the RCA."
      5. Wire your real Grafana contact point to the alert-triage workflow webhook for a true end-to-end demo (see ./README.md).

  EOT
}

output "sre_agent_names" {
  value = module.sre_agents.agent_names
}

output "grafana_integration_name" {
  value = module.grafana_integration.integration_name
}

output "slack_integration_name" {
  value = module.slack_integration.integration_name
}
