output "agent_names" {
  description = "Names of the SaaS SRE agents provisioned by this module."
  value = {
    alert_ingest = sg_agent.saas_alert_ingest.name
    investigator = sg_agent.saas_investigator.name
    remediator   = sg_agent.saas_remediator.name
  }
}

output "workflow_names" {
  description = "Workflow names provisioned by this module."
  value = {
    pagerduty_saas_incident_response = sg_workflow.pagerduty_saas_incident_response.name
  }
}

output "datadog_integration_name" {
  description = "Resolved Datadog Guild integration name."
  value       = local.resolved_datadog_integration_name
}

output "pagerduty_integration_name" {
  description = "Resolved PagerDuty Guild integration name."
  value       = local.resolved_pagerduty_integration_name
}

output "confluence_integration_name" {
  description = "Resolved Confluence Guild integration name."
  value       = local.resolved_confluence_integration_name
}

output "azure_integration_name" {
  description = "Resolved Azure Guild integration name."
  value       = local.resolved_azure_integration_name
}

output "webhook_id" {
  description = "PagerDuty ingress webhook id when enable_pagerduty_webhook is true; empty string otherwise."
  value       = var.enable_pagerduty_webhook ? sg_webhook.pagerduty_saas_alerts[0].id : ""
}

output "webhook_token" {
  description = "PagerDuty ingress webhook token when enable_pagerduty_webhook is true."
  value       = var.enable_pagerduty_webhook ? sg_webhook.pagerduty_saas_alerts[0].token : ""
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
    var.enable_pagerduty_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.pagerduty_saas_alerts[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.pagerduty_saas_alerts[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
