output "agent_names" {
  description = "Names of agents created by this module."
  value = {
    db_state_split_architect = sg_agent.db_state_split_architect.name
  }
}

output "stackgen_mcp_auto_approve_policy_id" {
  description = "Intervention policy id for stackgen-mcp_* HITL waiver (db-state-split-stackgen-mcp-auto-approve)."
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
  value       = local.resolved_github_integration_name
}

output "ubuntu_integration_name" {
  description = <<-EOT
    Name of the Ubuntu Guild integration the agent uses. Equals
    `var.existing_ubuntu_integration_name` when supplied; otherwise the
    module-provisioned `<module_prefix>-ubuntu[-<suffix>]` integration name.
  EOT
  value       = local.resolved_ubuntu_integration_name
}

output "aws_integration_name" {
  description = <<-EOT
    Name of the AWS Guild integration the agent uses. Equals
    `var.existing_aws_integration_name` when supplied; otherwise the
    module-provisioned `<module_prefix>-aws[-<suffix>]` integration name.
  EOT
  value       = local.resolved_aws_integration_name
}
