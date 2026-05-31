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

output "webhook_trigger_endpoint" {
  description = "Non-sensitive `POST …/api/v1/webhooks/trigger` URL when `webhook_trigger_base_url` is set; empty string otherwise."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with `apiKey` when `webhook_trigger_base_url` is set and the webhook token is non-empty; null otherwise."
  sensitive   = true
  value = (
    trimspace(var.webhook_trigger_base_url) != "" && trimspace(try(sg_webhook.github_pr_issue.token, "")) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.github_pr_issue.token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
