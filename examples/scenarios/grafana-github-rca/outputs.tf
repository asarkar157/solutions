output "next_steps" {
  description = "Copy-paste runbook to wire the SRE app and start the demo."
  value       = <<-EOT

    Grafana -> GitHub RCA demo provisioned. Next steps:

      1. Open Guild:            ${var.stackgen_url}
         - Policies tab:        confirm the guardrail set is attached (HITL on remediation / PR).
         - Integrations tab:    grafana, github${length(module.slack_integration) > 0 ? ", slack" : ""} are connected.

      2. Open the SRE app UI — run Discovery once (Discovery page) so Grafana /
         GitHub inventory is populated for ${var.tracked_github_repo}.${var.enable_grafana_alert_webhook && var.enable_sre_app_bindings ? " Grafana alert webhook was registered via sg_sre_alert_webhook — see output grafana_alert_webhook_trigger_url." : " In Grafana, point a contact-point webhook at the SRE app alert-ingest URL if not already configured."}

      3. Trigger the alert. In the SRE app: watch ingest -> investigation ->
         substantive RCA (Grafana telemetry correlated with GitHub commits) ->
         RCA posted back to Grafana -> fix PR opened on GitHub
         (approve the HITL prompt in Guild to let it open).

      4. Platform wow factors in Guild UI: Workflows (investigate), Audit logs,
         Activity playback of the investigation run.
  EOT
}

output "grafana_alert_webhook_trigger_url" {
  description = "Absolute Guild trigger URL for Grafana contact-point webhooks (null when alert webhook not registered)."
  value = (
    var.enable_sre_app_bindings && var.enable_grafana_alert_webhook
    ? try(module.sre_app_bindings[0].alert_webhook_trigger_urls["grafana:${module.grafana_integration.integration_name}"], null)
    : null
  )
  sensitive = true
}

output "grafana_integration_name" {
  description = "Guild Grafana integration used for alert telemetry during RCA."
  value       = module.grafana_integration.integration_name
}

output "github_integration_name" {
  description = "Guild GitHub integration used for commit correlation and the RCA fix PR."
  value       = module.github_integration.integration_name
}

output "slack_enabled" {
  description = "Whether the Slack integration was created (depends on slack_bot_token)."
  value       = length(module.slack_integration) > 0
}

output "sre_app_bindings_enabled" {
  description = "Whether sg_app bindings to the stackgen-sre-app were applied."
  value       = var.enable_sre_app_bindings
}

output "sre_app_integration_names" {
  description = "Integration names bound to the SRE app install (empty when enable_sre_app_bindings = false)."
  value       = var.enable_sre_app_bindings ? module.sre_app_bindings[0].integration_names : []
}

output "tracked_target" {
  description = "The Grafana workload and GitHub repo this demo tracks: scope alert rules and SRE-app discovery to these labels."
  value = {
    service     = var.tracked_service
    env         = var.tracked_env
    github_repo = var.tracked_github_repo
    grafana_url = var.grafana_server
    alert_scope = "service=${var.tracked_service} env=${var.tracked_env}"
  }
}

output "investigator_agent_name" {
  description = "SRE app investigator agent — attach the remote runner to this agent in Guild after apply."
  value       = var.investigator_agent_name
}


output "gateway_slack_event_url" {
  description = "Slack App Event Subscriptions Request URL (routes to aiden-router). Null when gateway_base_url is empty."
  value       = trimspace(var.gateway_base_url) != "" ? "${trimspace(var.gateway_base_url)}/slack/events" : null
}

output "gateway_registration_checklist" {
  description = "Copy-paste Slack + Gateway wiring after apply."
  value = trimspace(var.gateway_base_url) != "" ? format(<<-EOT

    Gateway + Slack (omnichannel chat):
      1. Guild Settings → Connect Slack → Add to Slack (OAuth; no manual bot token env)
      2. Slack Event URL: %s/slack/events  (paste from Settings Advanced URLs if needed)
      3. Invite Aiden bot to #sre-alerts
      4. Fire test alert via Grafana webhook (automation path — see grafana_alert_webhook_trigger_url)
      5. In Slack: "@Aiden investigate the firing alert" (chat path)

    See docs/omnichannel-triage.md

  EOT
  , trimspace(var.gateway_base_url)) : null
}
