output "agent_names" {
  description = "Names of the PrivateSaaS DevOps/SRE agents provisioned by this module."
  value = {
    alert_ingest = sg_agent.grafana_alert_ingest.name
    investigator = sg_agent.privatesaas_investigator.name
    remediator   = sg_agent.privatesaas_remediator.name
  }
}

output "workflow_names" {
  description = "Workflow names provisioned by this module."
  value = {
    privatesaas_incident_response  = sg_workflow.privatesaas_incident_response.name
    privatesaas_connectivity_audit = sg_workflow.privatesaas_connectivity_audit.name
  }
}

output "grafana_integration_name" {
  description = "Resolved Grafana Guild integration name."
  value       = local.resolved_grafana_integration_name
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = local.resolved_aws_integration_name
}

output "paloalto_integration_name" {
  description = "Resolved Palo Alto Guild integration name."
  value       = local.resolved_paloalto_integration_name
}

output "webhook_id" {
  description = "Grafana ingress webhook id when enable_grafana_webhook is true; empty string otherwise."
  value       = var.enable_grafana_webhook ? sg_webhook.grafana_privatesaas_alerts[0].id : ""
}

output "webhook_token" {
  description = "Grafana ingress webhook token when enable_grafana_webhook is true."
  value       = var.enable_grafana_webhook ? sg_webhook.grafana_privatesaas_alerts[0].token : ""
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
    var.enable_grafana_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.grafana_privatesaas_alerts[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.grafana_privatesaas_alerts[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
