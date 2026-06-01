output "agent_names" {
  description = "Names of the multi-tenant SRE RCA agents provisioned by this module."
  value = {
    alert_ingest = sg_agent.datadog_alert_ingest.name
    investigator = sg_agent.rca_investigator.name
    publisher    = sg_agent.rca_publisher.name
    collaborator = sg_agent.rca_collaborator.name
  }
}

output "workflow_names" {
  description = "Workflow names provisioned by this module."
  value = {
    datadog_multitenant_rca   = sg_workflow.datadog_multitenant_rca.name
    datadog_rca_collaboration = sg_workflow.datadog_rca_collaboration.name
  }
}

output "datadog_integration_name" {
  description = "Resolved Datadog Guild integration name."
  value       = local.resolved_datadog_integration_name
}

output "gcp_integration_name" {
  description = "Resolved GCP Guild integration name."
  value       = local.resolved_gcp_integration_name
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = local.resolved_aws_integration_name
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = local.resolved_github_integration_name
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = local.resolved_slack_integration_name
}

output "evidence_checklist_name" {
  description = "Evidence checklist name when enable_evidence_checklist is true; empty string otherwise."
  value       = var.enable_evidence_checklist ? sg_evidence_checklist.multitenant_rca[0].name : ""
}

output "webhook_id" {
  description = "Datadog ingress webhook id when enable_datadog_webhook is true; empty string otherwise."
  value       = var.enable_datadog_webhook ? sg_webhook.datadog_alert_receiver[0].id : ""
}

output "webhook_token" {
  description = "Datadog ingress webhook token when enable_datadog_webhook is true."
  value       = var.enable_datadog_webhook ? sg_webhook.datadog_alert_receiver[0].token : ""
  sensitive   = true
}

output "collaboration_webhook_id" {
  description = "Slack collaboration ingress webhook id when enable_slack_collaboration_webhook is true; empty string otherwise."
  value       = var.enable_slack_collaboration_webhook ? sg_webhook.slack_rca_thread[0].id : ""
}

output "collaboration_webhook_token" {
  description = "Slack collaboration ingress webhook token when enable_slack_collaboration_webhook is true."
  value       = var.enable_slack_collaboration_webhook ? sg_webhook.slack_rca_thread[0].token : ""
  sensitive   = true
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive `POST …/api/v1/webhooks/trigger` URL when `webhook_trigger_base_url` is set; empty string otherwise."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with `apiKey` for the Datadog webhook when `webhook_trigger_base_url` is set and the webhook token is non-empty; null otherwise."
  sensitive   = true
  value = (
    var.enable_datadog_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.datadog_alert_receiver[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.datadog_alert_receiver[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "collaboration_webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with `apiKey` for the Slack collaboration webhook when `webhook_trigger_base_url` is set and the webhook token is non-empty; null otherwise."
  sensitive   = true
  value = (
    var.enable_slack_collaboration_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.slack_rca_thread[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.slack_rca_thread[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
