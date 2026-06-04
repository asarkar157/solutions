output "agent_names" {
  description = "SDLC agent names for cross-module references"
  value = {
    cloud_infra          = sg_agent.cloud_infra.name
    k8s_ops              = sg_agent.k8s_ops.name
    github_scm           = sg_agent.github_scm.name
    qa_testing           = sg_agent.qa_testing.name
    docs_writer          = sg_agent.docs_writer.name
    ui_frontend          = sg_agent.ui_frontend.name
    linear_pm            = sg_agent.linear_pm.name
    datadog_alert_triage = sg_agent.datadog_alert_triage.name
    github_pr_reminder   = sg_agent.github_pr_reminder.name
  }
}

output "workflow_names" {
  description = "Workflow names for cross-module references"
  value = {
    release_pipeline         = sg_workflow.release_pipeline.name
    developer_request_intake = sg_workflow.developer_request_intake.name
  }
}

output "runbook_names" {
  description = "SDLC-owned runbook names (e.g. StackGen MCP IaC playbook)"
  value = {
    stackgen_mcp_iac = sg_runbook_sop.stackgen_mcp_iac.name
  }
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = nonsensitive(local.resolved_slack_integration_name)
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = nonsensitive(local.resolved_aws_integration_name)
}

output "gcp_integration_name" {
  description = "Resolved GCP Guild integration name."
  value       = nonsensitive(local.resolved_gcp_integration_name)
}
