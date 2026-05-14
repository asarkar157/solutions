output "agent_name" {
  description = "Guild name of the pipeline-insights agent."
  value       = sg_agent.pipeline_insights.name
}

output "workflow_name" {
  description = "Name of the github-pipeline-insights workflow. Pass to aios-agent-schedules with target_type = \"workflow\" for periodic CI/deploy reports."
  value       = sg_workflow.pipeline_insights.name
}

output "runbook_names" {
  description = "Runbook SOP names registered by this module."
  value = {
    workflow_run_status_lookup = sg_runbook_sop.workflow_run_status_lookup.name
    pr_merge_intelligence      = sg_runbook_sop.pr_merge_intelligence.name
    deployment_status_lookup   = sg_runbook_sop.deployment_status_lookup.name
  }
}

output "github_integration_name" {
  description = "Name of the GitHub Guild integration the agent uses (resolved across the existing-override / module-provisioned paths)."
  value       = local.resolved_github_integration_name
}

output "slack_integration_name" {
  description = "Name of the Slack Guild integration the agent uses, or empty string when no Slack integration is wired."
  value       = local.resolved_slack_integration_name
}

output "webhook" {
  description = "Slack-bridge webhook ingress (only present when enable_slack_webhook = true)."
  value = var.enable_slack_webhook ? {
    id    = sg_webhook.slack_pipeline_insights[0].id
    token = sg_webhook.slack_pipeline_insights[0].token
  } : null
  sensitive = true
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive `POST …/api/v1/webhooks/trigger` URL when `webhook_trigger_base_url` is set; empty string otherwise."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with `apiKey` when `webhook_trigger_base_url` is set and `enable_slack_webhook` produced a non-empty token; null otherwise."
  sensitive   = true
  value = (
    var.enable_slack_webhook && trimspace(var.webhook_trigger_base_url) != "" && trimspace(sg_webhook.slack_pipeline_insights[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.slack_pipeline_insights[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
