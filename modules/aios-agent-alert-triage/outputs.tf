output "agent_name" {
  description = "Name of the alert-triage coordinator agent (legacy alias)."
  value       = sg_agent.alert_triage_coordinator.name
}

output "agent_names" {
  description = "Names of all agents provisioned by this module."
  value = {
    coordinator  = sg_agent.alert_triage_coordinator.name
    alert_ingest = sg_agent.grafana_alert_ingest.name
    investigator = sg_agent.rca_investigator.name
  }
}

output "workflow_name" {
  description = "Name of the cross-platform alert-triage workflow."
  value       = sg_workflow.alert_triage_pipeline.name
}

output "runbook_sop_names" {
  description = "Names of alert-triage runbook SOPs."
  value = {
    alert_normalization          = sg_runbook_sop.alert_normalization.name
    search_prior_incidents       = sg_runbook_sop.search_prior_incidents.name
    symptom_cause_classification = sg_runbook_sop.symptom_cause_classification.name
    grafana_signals              = sg_runbook_sop.grafana_signals.name
    grafana_query_probe          = sg_runbook_sop.grafana_query_probe.name
    grafana_datasource_probe     = sg_runbook_sop.grafana_datasource_probe.name
    cross_signal_investigation   = sg_runbook_sop.cross_signal_investigation.name
    hypothesis_tree_rca          = sg_runbook_sop.hypothesis_tree_rca.name
    synthesize_rca               = sg_runbook_sop.synthesize_rca.name
    persist_incident_memory      = sg_runbook_sop.persist_incident_memory.name
    grafana_alert_routing        = sg_runbook_sop.grafana_alert_routing.name
    publish_slack_rca            = sg_runbook_sop.publish_slack_rca.name
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

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name (empty when not wired)."
  value       = local.resolved_aws_integration_name
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name (empty when not wired)."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "knowledge_base_id" {
  description = "Optional sg_knowledge_base id when enable_knowledge_base is true."
  value       = var.enable_knowledge_base ? sg_knowledge_base.grafana_alert_rca[0].id : null
}

output "remote_runner_name" {
  description = "Remote runner name when remote_runner_name is set."
  value       = trimspace(var.remote_runner_name) != "" && length(module.remote_runner) > 0 ? module.remote_runner[0].runner_name : null
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
