output "next_steps" {
  description = "Copy-paste runbook to wire the SRE app and start the demo."
  value       = <<-EOT

    Datadog -> RCA demo provisioned. Next steps:

      1. Open Guild:            ${var.stackgen_url}
         - Integrations tab:    datadog (from SRE onboarding) + github${local.enable_aws ? " + aws" : ""}${length(module.slack_integration) > 0 ? " + slack" : ""}.${var.enable_policies ? "\n         - Policies tab:        guardrails from this apply (enable_policies = true)." : ""}

      2. SRE app (${var.sre_app_name}) must already be installed with Datadog wired.${var.enable_sre_app_bindings ? " GitHub" : ""}${var.enable_sre_app_bindings && local.enable_aws ? " / AWS" : ""}${var.enable_sre_app_bindings && length(module.slack_integration) > 0 ? " / Slack" : ""}${var.enable_sre_app_bindings ? " merged onto existing bindings via sg_app." : " Set enable_sre_app_bindings = true to attach GitHub."}
         ${var.create_remote_runner && var.enable_sre_app_bindings ? "Remote runner \"${var.remote_runner_name}\" merged onto \"${var.investigator_agent_name}\" when aiden-runner is running — see remote_runner_docker_run_command." : var.create_remote_runner ? "Start aiden-runner — see remote_runner_docker_run_command." : ""}

      3. Open the SRE app UI — run Discovery once (Discovery page) so Datadog /
         AWS / GitHub inventory is populated.${var.enable_datadog_alert_webhook && var.enable_sre_app_bindings ? " Datadog alert webhook was registered via sg_sre_alert_webhook — see output datadog_alert_webhook_trigger_url." : " In Datadog, point a monitor webhook at the SRE app alert-ingest URL if not already configured."}

      4. Trigger the monitor. In the SRE app: watch ingest -> investigation ->
         substantive RCA -> RCA posted back to Datadog as an event -> fix PR
         opened on GitHub (approve the HITL prompt in Guild to let it open).

      5. Platform wow factors in Guild UI: Workflows (investigate + finops),
         Cost management, Audit logs, Activity playback of the investigation run.
    ${var.enable_finops ? "\n      FinOps: weekly review cron 'weekly-finops-review' (Mondays 09:00 UTC).\n" : ""}
  EOT
}

output "datadog_integration_name" {
  description = "Existing Guild Datadog integration bound to the SRE app (from data.sg_guild_integration)."
  value       = local.datadog_integration_name
}

output "datadog_alert_webhook_trigger_url" {
  description = "Absolute Guild trigger URL for Datadog monitor webhooks (null when alert webhook not registered)."
  value = (
    var.enable_sre_app_bindings && var.enable_datadog_alert_webhook
    ? try(module.sre_app_bindings[0].alert_webhook_trigger_urls["datadog:${local.datadog_integration_name}"], null)
    : null
  )
  sensitive = true
}

output "aws_integration_name" {
  description = "Guild AWS integration the incident is investigated against (null when aws_role_arn is empty)."
  value       = local.enable_aws ? module.aws_integration[0].integration_name : null
}

output "github_integration_name" {
  description = "Guild GitHub integration used for repo context and the RCA fix PR."
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

output "finops_workflow_name" {
  description = "FinOps review workflow name (empty when enable_finops = false)."
  value       = var.enable_finops ? module.cost_optimizer[0].workflow_name : ""
}

output "tracked_target" {
  description = "The Datadog workload this demo tracks: scope monitors and SRE-app discovery to these tags."
  value = {
    service       = var.tracked_service
    env           = var.tracked_env
    namespace     = var.tracked_namespace
    datadog_site  = var.datadog_site
    monitor_scope = "service:${var.tracked_service} env:${var.tracked_env}"
  }
}

output "service_repository_map" {
  description = "Service→GitHub repo hints passed to sg_app.config for closed-loop remediation."
  value       = var.service_repository_map
}

output "demo_golden_fix_url" {
  description = "Golden schema-mismatch fix path for the order-service aiden-demo fault."
  value       = "https://github.com/stackgen-demo/order-service/blob/main/cmd/initdb/main.go"
}

output "investigator_policies_attached" {
  description = "Policy keys attached to the SRE investigator via aios-sre-app-bindings (empty when enable_policies or enable_sre_app_bindings is false)."
  value       = var.enable_sre_app_bindings && var.enable_policies ? module.sre_app_bindings[0].investigator_policies_attached : []
}

output "investigator_remote_runners" {
  description = "Remote runners on the investigator after merge (empty when bindings or runner disabled)."
  value       = var.enable_sre_app_bindings && var.create_remote_runner ? module.sre_app_bindings[0].investigator_remote_runners : []
}

output "investigator_agent_name" {
  description = "SRE app investigator agent — policies and remote runner attach via aios-sre-app-bindings."
  value       = var.investigator_agent_name
}

output "remote_runner_name" {
  description = "Registered remote runner name (empty when create_remote_runner is false)."
  value       = var.create_remote_runner ? module.remote_runner[0].runner_name : null
}

output "remote_runner_docker_run_command" {
  description = "Docker command to start aiden-runner after apply."
  value       = var.create_remote_runner ? local.remote_runner_docker_run_command : null
  sensitive   = true
}

output "remote_runner_cli_start_command" {
  description = "aiden-runner CLI start command with registration token."
  value       = var.create_remote_runner ? module.remote_runner[0].cli_start_command_with_secrets : null
  sensitive   = true
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
      4. Fire test alert via Datadog webhook (automation path — see datadog_alert_webhook_trigger_url)
      5. In Slack: "@Aiden investigate the firing alert" (chat path)

    See docs/omnichannel-triage.md

  EOT
  , trimspace(var.gateway_base_url)) : null
}
