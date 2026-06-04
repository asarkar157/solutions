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
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = nonsensitive(local.resolved_aws_integration_name)
}

output "remote_runner_name" {
  description = "Configured remote runner name when set."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].runner_name : ""
}

output "remote_runner_cli_start_command" {
  description = "aiden-runner start command when create_remote_runner is true."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].cli_start_command : null
  sensitive   = true
}

output "remote_runner_helm_install_command" {
  description = "Helm install command when create_remote_runner is true."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].helm_install_command : null
  sensitive   = true
}
