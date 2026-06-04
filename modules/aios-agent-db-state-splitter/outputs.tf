output "agent_names" {
  description = "Names of agents created by this module."
  value = {
    db_state_split_architect = sg_agent.db_state_split_architect.name
  }
}

output "remote_runner_name" {
  description = "Resolved remote runner name (module default or var.remote_runner_name)."
  value       = module.remote_runner.runner_name
}

output "shell_tool_prefix" {
  description = "Remote runner tool prefix for execute_command|series|parallel|create_files (same as remote_runner_name)."
  value       = local.shell_tool_prefix
}

output "remote_runner_created" {
  description = "True when this apply registered sg_remote_runner (create_remote_runner = true)."
  value       = module.remote_runner.created
}

output "remote_runner_mothership_url" {
  description = "Mothership URL from provider stackgen_url when runner was created in this apply."
  value       = module.remote_runner.mothership_url
}

output "remote_runner_cli_start_command" {
  description = "aiden-runner start command when create_remote_runner is true."
  value       = module.remote_runner.cli_start_command
  sensitive   = true
}

output "remote_runner_helm_install_command" {
  description = "Helm install command when create_remote_runner is true."
  value       = module.remote_runner.helm_install_command
  sensitive   = true
}

output "remote_runner_cli_start_command_with_secrets" {
  description = "aiden-runner start command with secrets sync flags when vault bindings are configured."
  value       = module.remote_runner.cli_start_command_with_secrets
  sensitive   = true
}

output "remote_runner_secrets_bound" {
  description = "True when sg_remote_runner_secrets was applied (git/aws vault refs on the runner)."
  value       = module.remote_runner.runner_secrets_bound
}

output "remote_runner_typed_secret_refs" {
  description = "Typed vault secret bindings on the remote runner (github/aws slots, etc.)."
  value       = module.remote_runner.typed_secret_refs
  sensitive   = true
}

output "runner_git_env_secret_id" {
  description = "Vault secret ID for runner GIT_TOKEN sync (created or runner_git_env_secret_id input)."
  value       = local.runner_git_env_secret_id
  sensitive   = true
}

output "runner_aws_env_secret_id" {
  description = "Vault secret ID for runner AWS_* sync (created or runner_aws_env_secret_id input)."
  value       = local.runner_aws_env_secret_id
  sensitive   = true
}

output "runner_script_pack_env_secret_id" {
  description = "Vault secret ID for runner DBSPLIT_SCRIPT_PACK_* sync (created or runner_script_pack_env_secret_id input)."
  value       = local.runner_script_pack_env_secret_id
  sensitive   = true
}

output "stackgen_mcp_auto_approve_policy_id" {
  description = "Intervention policy id for stackgen-mcp_* companion policy (db-state-split-stackgen-mcp-auto-approve); MCP tools are auto-approved via sg_agent.auto_approve_tools."
  value       = sg_policy.db_state_split_stackgen_mcp_auto_approve.id
}

output "workflow_names" {
  description = "Primary and secondary workflow names."
  value = {
    db_monorepo_state_split_convergence = sg_workflow.db_monorepo_state_split_convergence.name
    orphan_iac_module_authoring         = sg_workflow.orphan_iac_module_authoring.name
  }
}

output "webhook_id" {
  description = "GitHub webhook id when enable_github_webhook is true; empty string otherwise."
  value       = var.enable_github_webhook ? sg_webhook.github_db_state_split[0].id : ""
}

output "webhook_token" {
  description = "Webhook HMAC secret when enable_github_webhook is true."
  value       = var.enable_github_webhook ? sg_webhook.github_db_state_split[0].token : ""
  sensitive   = true
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive `POST …/api/v1/webhooks/trigger` URL when `webhook_trigger_base_url` is set; empty string otherwise."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with `apiKey` when `webhook_trigger_base_url` is set and `enable_github_webhook` produced a non-empty token; null otherwise."
  sensitive   = true
  value = (
    var.enable_github_webhook && trimspace(var.webhook_trigger_base_url) != "" && trimspace(sg_webhook.github_db_state_split[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.github_db_state_split[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "github_integration_name" {
  description = <<-EOT
    Name of the GitHub Guild integration the agent uses. Equals
    `var.existing_github_integration_name` when supplied; otherwise the
    module-provisioned `<module_prefix>-github[-<suffix>]` integration name.
  EOT
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "aws_integration_name" {
  description = <<-EOT
    Name of the AWS Guild integration the agent uses. Equals
    `var.existing_aws_integration_name` when supplied; otherwise the
    module-provisioned `<module_prefix>-aws[-<suffix>]` integration name.
  EOT
  value       = nonsensitive(local.resolved_aws_integration_name)
}
