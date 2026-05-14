output "agent_names" {
  description = "Names of the agents created in this module."
  value = {
    terraform_module_manager = sg_agent.terraform_module_manager.name
  }
}

output "workflow_name" {
  description = "Guild workflow name."
  value       = sg_workflow.terraform_module_update.name
}

output "github_integration_name" {
  description = "Final Guild GitHub integration name (`terraform-bot-github[-<suffix>]` or the consumer override)."
  value       = local.resolved_github_integration_name
}

output "ubuntu_integration_name" {
  description = "Final Guild Ubuntu CLI integration name (`terraform-bot-ubuntu[-<suffix>]` or the consumer override)."
  value       = local.resolved_ubuntu_integration_name
}

output "webhook_id" {
  description = "The ID of the GitHub webhook"
  value       = sg_webhook.github_pr_issue.id
}

output "webhook_token" {
  description = "The secret token for the GitHub webhook"
  value       = sg_webhook.github_pr_issue.token
  sensitive   = true
}
