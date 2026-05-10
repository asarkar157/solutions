output "agent_name" {
  description = "The name of the StackGen MCP Agent"
  value       = sg_agent.stackgen_expert.name
}

output "policy_id" {
  description = "The ID of the applied guardrail policy"
  value       = sg_policy.stackgen_guardrails.id
}

output "integration_name" {
  description = "The name of the StackGen MCP integration"
  value       = sg_guild_integration.stackgen_mcp.name
}
