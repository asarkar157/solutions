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

output "webhook" {
  description = "Slack-bridge webhook ingress (only present when enable_slack_webhook = true)."
  value = var.enable_slack_webhook ? {
    id    = sg_webhook.slack_pipeline_insights[0].id
    token = sg_webhook.slack_pipeline_insights[0].token
  } : null
  sensitive = true
}
