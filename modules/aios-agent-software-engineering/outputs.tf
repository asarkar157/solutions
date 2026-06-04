output "agent_names" {
  value = { linear_planner = sg_agent.linear_planner.name, cursor_developer = sg_agent.cursor_developer.name }
}

output "workflow_name" {
  description = "Name of the feature-development workflow."
  value       = sg_workflow.feature_development.name
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = nonsensitive(local.resolved_slack_integration_name)
}

output "linear_mcp_integration_name" {
  description = "Linear MCP Guild integration name (passthrough)."
  value       = nonsensitive(local.resolved_linear_mcp_integration_name)
}

output "cursor_mcp_integration_name" {
  description = "Cursor MCP Guild integration name (passthrough)."
  value       = nonsensitive(local.resolved_cursor_mcp_integration_name)
}
