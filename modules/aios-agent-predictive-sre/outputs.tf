output "agent_name" { value = sg_agent.predictive_analyst.name }

output "workflow_name" {
  description = "Name of the predictive incident-triage workflow."
  value       = sg_workflow.predictive_triage.name
}

output "runbook_sop_names" {
  description = "Names of the predictive SRE runbook SOPs."
  value = {
    cross_domain_correlation        = sg_runbook_sop.cross_domain_correlation.name
    predictive_degradation_analysis = sg_runbook_sop.predictive_degradation.name
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

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = nonsensitive(local.resolved_aws_integration_name)
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = nonsensitive(local.resolved_slack_integration_name)
}
