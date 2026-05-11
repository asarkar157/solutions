output "agent_names" {
  description = "Names of the agents created in this module"
  value = {
    terraform_module_manager = sg_agent.terraform_module_manager.name
  }
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
