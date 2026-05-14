output "agent_name" {
  description = "Name of the iac-drift-detective agent."
  value       = sg_agent.iac_drift_detective.name
}

output "workflow_name" {
  description = "Name of the iac-drift-remediation workflow."
  value       = sg_workflow.drift_remediation.name
}

output "runbook_sop_names" {
  description = "Names of the iac-drift-detective runbook SOPs."
  value = {
    drift_scan = sg_runbook_sop.drift_scan.name
  }
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = local.resolved_github_integration_name
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = local.resolved_aws_integration_name
}
