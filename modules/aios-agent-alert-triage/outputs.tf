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
