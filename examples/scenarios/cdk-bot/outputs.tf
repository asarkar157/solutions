output "webhook_ingress_payload_url" {
  value     = module.cdk_bot.webhook_ingress_payload_url
  sensitive = true
}

output "agent_names" {
  value = module.cdk_bot.agent_names
}

output "workflow_name" {
  value = module.cdk_bot.workflow_name
}

output "remote_runner_name" {
  value = module.cdk_bot.remote_runner_name
}

output "remote_runner_token" {
  description = "aiden-runner registration token for cdk-bot-runner (STACKGEN_RUNNER_TOKEN)."
  value       = module.cdk_bot.remote_runner_token
  sensitive   = true
}

output "runner_docker_image" {
  description = "CDK runner Docker image (repository:tag) built during apply."
  value       = module.cdk_bot.runner_docker_image
}

output "remote_runner_docker_run_command" {
  description = "Copy-paste docker run for cdk-bot-runner (image + token + mothership)."
  value       = module.cdk_bot.remote_runner_docker_run_command
  sensitive   = true
}

output "remote_runner_cli_start_command_with_secrets" {
  description = "Full aiden-runner start command including mothership URL and runner token."
  value       = module.cdk_bot.remote_runner_cli_start_command_with_secrets
  sensitive   = true
}
