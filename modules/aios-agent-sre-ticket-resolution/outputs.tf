output "agent_names" {
  description = "Names of the SRE ticket resolution agents provisioned by this module."
  value = {
    intake       = sg_agent.ticket_intake.name
    investigator = sg_agent.ticket_investigator.name
    resolver     = sg_agent.ticket_resolver.name
  }
}

output "workflow_names" {
  description = "Workflow names provisioned by this module."
  value = {
    servicenow_ticket_resolution = sg_workflow.servicenow_ticket_resolution.name
  }
}

output "servicenow_integration_name" {
  description = "Resolved ServiceNow Guild integration name."
  value       = nonsensitive(local.resolved_servicenow_integration_name)
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = nonsensitive(local.resolved_aws_integration_name)
}

output "grafana_integration_name" {
  description = "Resolved Grafana Guild integration name."
  value       = nonsensitive(local.resolved_grafana_integration_name)
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = nonsensitive(local.resolved_slack_integration_name)
}

output "webhook_id" {
  description = "ServiceNow ingress webhook id when enable_servicenow_webhook is true; empty string otherwise."
  value       = var.enable_servicenow_webhook ? sg_webhook.servicenow_ticket_receiver[0].id : ""
}

output "webhook_token" {
  description = "ServiceNow ingress webhook token when enable_servicenow_webhook is true."
  value       = var.enable_servicenow_webhook ? sg_webhook.servicenow_ticket_receiver[0].token : ""
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
    var.enable_servicenow_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.servicenow_ticket_receiver[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.servicenow_ticket_receiver[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
