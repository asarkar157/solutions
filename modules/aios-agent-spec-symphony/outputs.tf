output "agent_names" {
  description = "Names of agents created by this module."
  value = {
    spec_symphony_orchestrator = sg_agent.spec_symphony_orchestrator.name
  }
}

output "workflow_name" {
  description = "Legacy Guild workflow name (spec-driven-feature)."
  value       = sg_workflow.spec_driven_feature.name
}

output "linear_product_spec_workflow_name" {
  description = "Linear product-spec workflow name."
  value       = nonsensitive(local.create_linear_product_spec ? sg_workflow.linear_product_spec[0].name : "")
}

output "linear_spec_implement_workflow_name" {
  description = "Linear spec-implement workflow name."
  value       = nonsensitive(local.create_linear_implement ? sg_workflow.linear_spec_implement[0].name : "")
}

output "evidence_checklist_name" {
  description = "Evidence checklist name for spec-driven-feature."
  value       = sg_evidence_checklist.spec_driven_feature_evidence.name
}

output "shell_tool_prefix" {
  description = "Remote runner tool prefix for execute_* tools."
  value       = nonsensitive(local.shell_tool_prefix)
}

output "runner_docker_image" {
  description = "Spec-symphony runner Docker image (repository:tag)."
  value       = local.runner_docker_image
}

output "runner_docker_build_triggered" {
  description = "True when docker build ran during apply."
  value       = local.build_spec_symphony_runner_image
}

output "github_webhook_id" {
  description = "GitHub webhook resource ID."
  value       = sg_webhook.github_receiver.id
}

output "github_webhook_token" {
  description = "GitHub webhook secret token."
  value       = sg_webhook.github_receiver.token
  sensitive   = true
}

output "linear_webhook_id" {
  description = "Linear webhook resource ID."
  value       = sg_webhook.linear_receiver.id
}

output "linear_webhook_token" {
  description = "Linear webhook secret token."
  value       = sg_webhook.linear_receiver.token
  sensitive   = true
}

output "webhook_trigger_endpoint" {
  description = "POST …/guild/api/v1/webhooks/trigger URL when webhook_trigger_base_url is set."
  value       = local.stackgen_webhook_trigger_url
}

output "github_webhook_trigger_url" {
  description = "Full GitHub webhook ingress URL with apiKey when base URL and token are set."
  sensitive   = true
  value = (
    trimspace(var.webhook_trigger_base_url) != ""
    && sg_webhook.github_receiver.token != null
    && trimspace(sg_webhook.github_receiver.token) != ""
    ) ? format(
    "%s?apiKey=%s%s",
    local.stackgen_webhook_trigger_url,
    urlencode(sg_webhook.github_receiver.token),
    local.stackgen_webhook_org_query
  ) : null
}

output "linear_webhook_trigger_url" {
  description = "Legacy linear_receiver webhook URL (spec-driven-feature)."
  sensitive   = true
  value       = local.legacy_linear_webhook_trigger_url
}

output "linear_product_spec_webhook_trigger_url" {
  description = "linear-product-spec webhook ingress URL."
  sensitive   = true
  value       = local.create_linear_product_spec ? local.linear_product_spec_webhook_trigger_url : null
}

output "linear_spec_implement_webhook_trigger_url" {
  description = "linear-spec-implement webhook ingress URL."
  sensitive   = true
  value       = local.create_linear_implement ? local.linear_spec_implement_webhook_trigger_url : null
}

output "remote_runner_name" {
  description = "Resolved remote runner name."
  value       = var.create_remote_runner ? module.remote_runner[0].runner_name : ""
}

output "remote_runner_token" {
  description = "aiden-runner registration token."
  value       = var.create_remote_runner ? module.remote_runner[0].runner_token : null
  sensitive   = true
}

output "remote_runner_cli_start_command_with_secrets" {
  description = "aiden-runner start command with secret sync."
  value       = var.create_remote_runner ? module.remote_runner[0].cli_start_command_with_secrets : null
  sensitive   = true
}

output "remote_runner_docker_run_command" {
  description = "docker run for spec-symphony runner image."
  value       = local.remote_runner_docker_run_command
  sensitive   = true
}

output "runner_script_pack_env_secret_id" {
  description = "Script pack env secret ID for runner sync."
  value       = local.runner_script_pack_env_secret_id
  sensitive   = true
}
