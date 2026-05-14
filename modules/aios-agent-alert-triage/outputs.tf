output "agent_name" {
  description = "Name of the alert-triage coordinator agent."
  value       = sg_agent.alert_triage_coordinator.name
}

output "workflow_name" {
  description = "Name of the cross-platform alert-triage workflow."
  value       = sg_workflow.alert_triage_pipeline.name
}

output "runbook_sop_names" {
  description = "Names of the alert-triage SOPs."
  value = {
    grafana_alert_routing = sg_runbook_sop.grafana_alert_routing.name
  }
}

output "grafana_integration_name" {
  description = "Resolved Grafana Guild integration name."
  value       = local.resolved_grafana_integration_name
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = local.resolved_slack_integration_name
}

output "webhook_id" {
  description = "ID of the sg_webhook receiving Grafana alert ingress for this workflow."
  value       = sg_webhook.grafana_alerts.id
}

output "webhook_token" {
  description = "Token for the Grafana alert ingress webhook. Configure this in Grafana's contact-points UI to deliver alerts."
  value       = sg_webhook.grafana_alerts.token
  sensitive   = true
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive `POST …/api/v1/webhooks/trigger` URL when `webhook_trigger_base_url` is set; empty string otherwise."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with `apiKey` when `webhook_trigger_base_url` is set and the webhook token is non-empty; null otherwise."
  sensitive   = true
  value = (
    trimspace(var.webhook_trigger_base_url) != "" && trimspace(sg_webhook.grafana_alerts.token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.grafana_alerts.token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
