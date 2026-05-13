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
