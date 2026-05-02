output "repository_to_iac_workflow" {
  description = "Invoke with required_input github_repo_url (HTTPS or owner/repo)."
  value       = module.repo_to_iac.workflow_names.repository_to_iac
}

output "repo_scan_appstack_github_export_workflow" {
  description = "Invoke with github_repo_url and export_github_repo; optional aws_region, stackgen_project_name."
  value       = module.repo_to_iac.workflow_names.repo_scan_appstack_github_export
}

output "repository_iac_architect_agent" {
  value = module.repo_to_iac.agent_names.repo_iac_architect
}

output "github_integration_name" {
  value = module.github_integration.integration_name
}
