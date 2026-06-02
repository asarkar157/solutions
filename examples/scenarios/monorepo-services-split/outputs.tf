output "agent_names" {
  value = module.monorepo_services_splitter.agent_names
}

output "workflow_names" {
  value = module.monorepo_services_splitter.workflow_names
}

output "github_integration_name" {
  value = module.monorepo_services_splitter.github_integration_name
}

output "ubuntu_integration_name" {
  value = module.monorepo_services_splitter.ubuntu_integration_name
}

output "demo_github_repo_url" {
  description = "Suggested repo URL for the SE talk track (from tfvars when set)."
  value       = var.github_repo_url
}
