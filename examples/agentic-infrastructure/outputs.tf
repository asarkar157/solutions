output "developer_request_intake_workflow" {
  description = "Workflow app teams invoke with natural-language infra asks (greenfield provisioning, brownfield upgrades, access, environments)."
  value       = module.sdlc.workflow_names.developer_request_intake
}

output "stackgen_mcp_iac_runbook" {
  description = "SDLC runbook name listing Consumer MCP tool workflow (stackgen-mcp_*)."
  value       = module.sdlc.runbook_names.stackgen_mcp_iac
}

output "cloud_infrastructure_engineer_agent" {
  description = "Agent that executes approved infra work against AWS via the integration after policy checks."
  value       = module.sdlc.agent_names.cloud_infra
}

output "aws_integration_name" {
  description = "Guild integration name passed to the cloud infrastructure engineer."
  value       = module.aws_integration.integration_name
}

output "aws_role_arn" {
  description = "IAM role ARN stored in StackGen Vault for the AWS MCP integration (same value passed to module.aws_integration)."
  value       = aws_iam_role.stackgen_aws_integration.arn
}

output "dangerous_ops_policy_name" {
  description = "Registered name of the dangerous-ops intervention policy attached to SDLC infra agents."
  value       = module.policies.policy_names.dangerous_ops
}

output "stackgen_mcp_integration_name" {
  description = "Guild integration name for StackGen MCP (empty if create_stackgen_mcp_integrations is false)."
  value       = var.create_stackgen_mcp_integrations ? sg_guild_integration.stackgen_mcp[0].name : ""
}

output "stackgen_mcp_url" {
  description = "Hosted MCP URL wired into the Vault secret (Consumer path)."
  value       = local.stackgen_mcp_url
}

output "github_integration_name" {
  description = "Guild GitHub integration name when github_token is set; empty otherwise."
  value       = nonsensitive(local.github_integration_enabled ? module.github_integration[0].integration_name : "")
}

output "repository_iac_architect_agent" {
  description = "repository-iac-architect agent when GitHub + repo-to-iac module is enabled."
  value       = nonsensitive(local.github_integration_enabled ? module.repo_to_iac[0].agent_names.repo_iac_architect : "")
}

output "repository_to_iac_workflow" {
  description = "repository-to-iac workflow name (requires github_token)."
  value       = nonsensitive(local.github_integration_enabled ? module.repo_to_iac[0].workflow_names.repository_to_iac : "")
}

output "repo_scan_appstack_github_export_workflow" {
  description = "repo-scan-appstack-github-export workflow name (requires github_token + MCP for full tool use)."
  value       = nonsensitive(local.github_integration_enabled ? module.repo_to_iac[0].workflow_names.repo_scan_appstack_github_export : "")
}
