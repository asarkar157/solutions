output "agent_name" {
  description = "Guild name of the slo-health agent."
  value       = sg_agent.slo_health.name
}

output "workflow_names" {
  description = "Workflow names registered by this module."
  value = {
    review          = sg_workflow.slo_health_review.name
    bootstrap       = var.enable_slo_bootstrap_workflow ? sg_workflow.slo_definition_bootstrap[0].name : ""
    drift_reconcile = var.enable_slo_drift_reconcile_workflow ? sg_workflow.slo_drift_reconcile[0].name : ""
  }
}

output "runbook_names" {
  description = "Runbook SOP names for review workflow (always) and optional bootstrap/drift workflows."
  value = {
    fetch_openslo_specs    = sg_runbook_sop.fetch_openslo_specs.name
    scan_grafana_config    = sg_runbook_sop.scan_grafana_config.name
    detect_config_drift    = sg_runbook_sop.detect_config_drift.name
    query_slo_metrics      = sg_runbook_sop.query_slo_metrics.name
    assess_error_budget    = sg_runbook_sop.assess_error_budget.name
    compose_slo_digest     = sg_runbook_sop.compose_slo_digest.name
    fetch_existing_catalog = var.enable_slo_bootstrap_workflow ? sg_runbook_sop.fetch_existing_catalog[0].name : ""
    open_slo_pr            = var.enable_slo_bootstrap_workflow ? sg_runbook_sop.open_slo_pr[0].name : ""
    fetch_catalog_drift    = var.enable_slo_drift_reconcile_workflow ? sg_runbook_sop.fetch_catalog_and_grafana[0].name : ""
    open_drift_pr          = var.enable_slo_drift_reconcile_workflow ? sg_runbook_sop.open_drift_pr[0].name : ""
  }
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "grafana_integration_name" {
  description = "Resolved Grafana Guild integration name."
  value       = nonsensitive(local.resolved_grafana_integration_name)
}

output "slack_integration_name" {
  description = "Resolved Slack integration name, or empty when not wired."
  value       = nonsensitive(local.resolved_slack_integration_name)
}

output "ubuntu_integration_name" {
  description = "Ubuntu CLI integration for PR runners, or empty."
  value       = nonsensitive(local.resolved_ubuntu_integration_name)
}

output "remote_runner_name" {
  description = "Remote runner name when create_remote_runner is configured."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].runner_name : ""
}

output "schedule_names" {
  description = "Cron schedule names when enable_weekly_schedule is true."
  value       = var.enable_weekly_schedule ? module.weekly_slo_review_schedule[0].schedule_names : toset([])
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive POST …/api/v1/webhooks/trigger URL when webhook_trigger_base_url is set."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "webhook_bootstrap" {
  description = "Bootstrap ingress webhook when enable_slo_bootstrap_webhook is true."
  value = var.enable_slo_bootstrap_workflow && var.enable_slo_bootstrap_webhook ? {
    id    = sg_webhook.slo_bootstrap_ingress[0].id
    token = sg_webhook.slo_bootstrap_ingress[0].token
  } : null
  sensitive = true
}

output "webhook_drift_reconcile" {
  description = "Drift reconcile ingress webhook when enable_slo_drift_reconcile_webhook is true."
  value = var.enable_slo_drift_reconcile_workflow && var.enable_slo_drift_reconcile_webhook ? {
    id    = sg_webhook.slo_drift_ingress[0].id
    token = sg_webhook.slo_drift_ingress[0].token
  } : null
  sensitive = true
}
