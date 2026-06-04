output "agent_names" {
  description = "Names of agents created by this module."
  value = merge(
    {
      monorepo_split_architect = sg_agent.monorepo_split_architect.name
      split_domain_analyst     = sg_agent.split_domain_analyst.name
    },
    var.enable_cursor_integration ? {
      cursor_split_executor = sg_agent.cursor_split_executor[0].name
    } : {},
  )
}

output "workflow_names" {
  description = "Analysis and extract workflow names."
  value = {
    monorepo_services_split_analysis = sg_workflow.monorepo_services_split_analysis.name
    monorepo_services_split_extract  = sg_workflow.monorepo_services_split_extract.name
  }
}

output "webhook_id" {
  description = "GitHub webhook id when enable_github_webhook is true; empty string otherwise."
  value       = var.enable_github_webhook ? sg_webhook.github_monorepo_split[0].id : ""
}

output "webhook_token" {
  description = "Webhook HMAC secret when enable_github_webhook is true."
  value       = var.enable_github_webhook ? sg_webhook.github_monorepo_split[0].token : ""
  sensitive   = true
}

output "github_integration_name" {
  description = "GitHub Guild integration name bound to agents."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "ubuntu_integration_name" {
  description = "Ubuntu Guild integration name used for script runners."
  value       = nonsensitive(local.resolved_ubuntu_integration_name)
}

output "readonly_default_policy_id" {
  description = "Intervention policy id blocking push to default branch."
  value       = sg_policy.monorepo_split_readonly_default.id
}

output "enable_cursor_integration" {
  description = "Whether cursor-split-executor was registered."
  value       = var.enable_cursor_integration
}

output "remote_runner_name" {
  description = "Remote runner name when create_remote_runner is true; empty otherwise."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].runner_name : ""
}

output "remote_runner_cli_start_command" {
  description = "aiden-runner CLI start command when create_remote_runner is true."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].cli_start_command : ""
}

output "remote_runner_helm_install_command" {
  description = "Helm install command for aiden-runner when create_remote_runner is true."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].helm_install_command : ""
}

output "cce_pack_version" {
  description = "Embedded CCE script pack version when enable_cce_enhanced is true."
  value       = var.enable_cce_enhanced ? module.cce_scripts[0].cce_pack_version : ""
}
