output "agent_names" {
  description = "Names of the agents created in this module."
  value = {
    cdk_module_manager = sg_agent.cdk_module_manager.name
  }
}

output "workflow_name" {
  description = "Guild workflow name."
  value       = sg_workflow.cdk_app_update.name
}

output "evidence_checklist_name" {
  description = "Guild evidence checklist name for cdk-app-update proof-of-work."
  value       = sg_evidence_checklist.cdk_app_update_evidence.name
}

output "runner_github_secret_id" {
  description = "sg_secret ID bound to the remote runner typed slot github (flat GIT_TOKEN/GH_TOKEN env)."
  value       = local.runner_github_secret_id
  sensitive   = true
}

output "runner_script_pack_env_secret_id" {
  description = "Vault secret ID for CDKBOT_SCRIPT_PACK_* generic runner sync (created or runner_script_pack_env_secret_id input)."
  value       = local.runner_script_pack_env_secret_id
  sensitive   = true
}

output "shell_tool_prefix" {
  description = "Tool prefix for remote runner execute_* tools."
  value       = nonsensitive(local.shell_tool_prefix)
}

output "runner_docker_image" {
  description = "CDK runner Docker image (repository:tag) built during apply."
  value       = local.runner_docker_image
}

output "runner_docker_build_triggered" {
  description = "True when this apply ran docker build for the CDK runner image."
  value       = local.build_cdk_runner_image
}

output "aws_integration_name" {
  description = "AWS integration name when enable_aws_validation is true; empty otherwise."
  value       = nonsensitive(local.resolved_aws_integration_name)
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

output "webhook_trigger_endpoint" {
  description = "Non-sensitive `POST …/guild/api/v1/webhooks/trigger` URL when `webhook_trigger_base_url` is set; empty string otherwise."
  value       = local.stackgen_webhook_trigger_url
}

output "remote_runner_name" {
  description = "Resolved remote runner name."
  value       = module.remote_runner.runner_name
}

output "remote_runner_token" {
  description = "aiden-runner registration token (STACKGEN_RUNNER_TOKEN). Sensitive — only available when create_remote_runner registered the runner in this state."
  value       = var.create_remote_runner ? module.remote_runner.runner_token : null
  sensitive   = true
}

output "remote_runner_created" {
  description = "True when this apply registered a new sg_remote_runner (`create_remote_runner = true`)."
  value       = module.remote_runner.created
}

output "remote_runner_mothership_url" {
  description = "Mothership URL embedded in install commands (provider stackgen_url). Empty when runner was not created in this apply."
  value       = module.remote_runner.mothership_url
}

output "remote_runner_cli_start_command" {
  description = "Copy-paste aiden-runner start command when `create_remote_runner` is true."
  value       = module.remote_runner.cli_start_command
  sensitive   = true
}

output "remote_runner_cli_start_command_with_secrets" {
  description = "aiden-runner start command with GitHub PAT sync flags when secrets are bound on the runner."
  value       = module.remote_runner.cli_start_command_with_secrets
  sensitive   = true
}

output "remote_runner_helm_install_command" {
  description = "Copy-paste Helm install for aiden-runner when `create_remote_runner` is true."
  value       = module.remote_runner.helm_install_command
  sensitive   = true
}

output "remote_runner_docker_run_command" {
  description = "Copy-paste docker run for the CDK runner image (includes --runner-token and --mothership)."
  value       = local.remote_runner_docker_run_command
  sensitive   = true
}
output "webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with `apiKey` when `webhook_trigger_base_url` is set and the webhook token is non-empty; null otherwise."
  sensitive   = true
  value = (
    trimspace(var.webhook_trigger_base_url) != ""
    && sg_webhook.github_pr_issue.token != null
    && trimspace(sg_webhook.github_pr_issue.token) != ""
    ) ? format(
    "%s?apiKey=%s%s",
    local.stackgen_webhook_trigger_url,
    urlencode(sg_webhook.github_pr_issue.token),
    local.stackgen_webhook_org_query
  ) : null
}
