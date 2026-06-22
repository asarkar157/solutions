output "target_repository_full_name" {
  description = "Configured test target repo for trigger-webhook.sh."
  value       = var.target_repository_full_name
}

output "agent_name" {
  value = module.spec_symphony.agent_names.spec_symphony_orchestrator
}

output "workflow_name" {
  value = module.spec_symphony.workflow_name
}

output "github_webhook_trigger_url" {
  value     = module.spec_symphony.github_webhook_trigger_url
  sensitive = true
}

output "linear_webhook_trigger_url" {
  description = "Legacy linear_receiver URL (disabled by default)."
  value       = module.spec_symphony.linear_webhook_trigger_url
  sensitive   = true
}

output "linear_product_spec_webhook_trigger_url" {
  value     = module.spec_symphony.linear_product_spec_webhook_trigger_url
  sensitive = true
}

output "linear_spec_implement_webhook_trigger_url" {
  value     = module.spec_symphony.linear_spec_implement_webhook_trigger_url
  sensitive = true
}

output "linear_product_spec_workflow_name" {
  value = module.spec_symphony.linear_product_spec_workflow_name
}

output "linear_spec_implement_workflow_name" {
  value = module.spec_symphony.linear_spec_implement_workflow_name
}

output "remote_runner_name" {
  value = module.spec_symphony.remote_runner_name
}

output "remote_runner_docker_run_command" {
  value     = module.spec_symphony.remote_runner_docker_run_command
  sensitive = true
}

output "runner_docker_image" {
  value = module.spec_symphony.runner_docker_image
}
