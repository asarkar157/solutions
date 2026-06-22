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

output "alert_triage_workflow_name" {
  description = "12-stage Grafana alert triage workflow (live webhook path)."
  value       = module.alert_triage.workflow_name
}

output "grafana_webhook_url" {
  description = "Grafana contact point URL for live alert ingest (when webhook token is configured)."
  value       = module.alert_triage.webhook_ingress_payload_url
}

output "poc_checklist" {
  description = "Incident Triage PoC dual-stack checklist (SRE app + eval harness)."
  value       = <<-EOT

    Incident Triage PoC checklist:
      1. Provision shared:incidents namespace in Guild (see stackgen-sre-app docs/endpoints-and-guild-integration.md)
      2. Install/reconcile SRE Copilot app so stackgen-sre--investigate-alert is available
      3. Run discovery once from SRE app UI (optional KG lift for eval v2)
      4. Build customer JSONL using scripts/incident-worksheet.md + incidents.schema.json
      5. Eval v1: stackgen-sre-app/scripts/poc-eval/run.sh --dataset incidents.jsonl
      6. Human scorecard: merge eval CSV with scripts/scorecard-template.csv columns
      7. Aggregate: scripts/aggregate-scores.sh scored.csv → update docs/incident-triage-poc-taxonomy.md
      8. Memory bootstrap: scripts/bootstrap-memory.sh --dataset incidents.jsonl
      9. Eval v2: re-run poc-eval with new --eval-run-id; compare aggregate lift
     10. Live demo: point Grafana contact point at ${module.alert_triage.webhook_ingress_payload_url != "" ? module.alert_triage.webhook_ingress_payload_url : "<webhook URL after apply>"}
     11. Leave-behind: scripts/render-scorecard.md → PDF for procurement
${trimspace(var.gateway_base_url) != "" ? "     12. Slack Event URL: ${trimspace(var.gateway_base_url)}/slack/events (→ aiden-router). See docs/omnichannel-triage.md\n" : ""}
    Scripts path: examples/scenarios/incident-triage/scripts/
    Honest limits: docs/incident-triage-poc-limits.md

  EOT
}

output "gateway_slack_event_url" {
  description = "Slack App Event Subscriptions Request URL (routes to aiden-router). Null when gateway_base_url is empty."
  value       = trimspace(var.gateway_base_url) != "" ? "${trimspace(var.gateway_base_url)}/slack/events" : null
}

output "gateway_registration_checklist" {
  description = "Copy-paste Slack + Gateway wiring after apply."
  value = trimspace(var.gateway_base_url) != "" ? format(<<-EOT

    Gateway + Slack (omnichannel chat):
      1. Slack Event URL: %s/slack/events  (routes to aiden-router)
      2. Set SLACK_SIGNING_SECRET on Gateway
      3. Invite Aiden bot to alert channels
      4. Apply this stack (alert-triage workflow + integrations)
      5. Fire test alert via Grafana webhook (automation path)
      6. In Slack: "@Aiden triage the firing alert" (chat path)

    See docs/omnichannel-triage.md

  EOT
  , trimspace(var.gateway_base_url)) : null
}
