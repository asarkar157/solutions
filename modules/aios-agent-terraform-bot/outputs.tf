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

output "evidence_checklist_name" {
  description = "Guild evidence checklist name for terraform-module-update proof-of-work."
  value       = sg_evidence_checklist.terraform_module_update_evidence.name
}

output "github_integration_name" {
  description = "Final Guild GitHub integration name (`terraform-bot-github[-<suffix>]` or the consumer override)."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "ubuntu_integration_name" {
  description = "Final Guild Ubuntu CLI integration name (`terraform-bot-ubuntu[-<suffix>]` or the consumer override)."
  value       = nonsensitive(local.resolved_ubuntu_integration_name)
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
  description = "Non-sensitive `POST …/api/v1/webhooks/trigger` URL when `webhook_trigger_base_url` is set; empty string otherwise."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "remote_runner_name" {
  description = "Configured remote runner name when `remote_runner_name` is set; empty string otherwise."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].runner_name : ""
}

output "remote_runner_created" {
  description = "True when this apply registered a new sg_remote_runner (`create_remote_runner = true`)."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].created : false
}

output "remote_runner_mothership_url" {
  description = "Mothership URL embedded in install commands (provider stackgen_url). Empty when runner was not created in this apply."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].mothership_url : ""
}

output "remote_runner_cli_start_command" {
  description = "Copy-paste aiden-runner start command when `create_remote_runner` is true."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].cli_start_command : null
  sensitive   = true
}

output "remote_runner_helm_install_command" {
  description = "Copy-paste Helm install for aiden-runner when `create_remote_runner` is true."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].helm_install_command : null
  sensitive   = true
}

output "iam_gate_workflow_name" {
  description = "Name of pre-deploy-iam-review workflow when enable_iam_gate_workflow is true."
  value       = local.iam_gate_enabled ? sg_workflow.pre_deploy_iam_review[0].name : ""
}

output "iam_gate_webhook_id" {
  description = "IAM gate webhook ID when enable_iam_gate_workflow is true."
  value       = local.iam_gate_enabled ? sg_webhook.github_iam_gate[0].id : ""
}

output "iam_gate_webhook_token" {
  description = "IAM gate webhook token when enable_iam_gate_workflow is true."
  value       = local.iam_gate_enabled ? sg_webhook.github_iam_gate[0].token : ""
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
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.github_pr_issue.token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
