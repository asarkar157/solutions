output "agent_name" {
  description = "Name of the supply-chain-security-analyst agent."
  value       = sg_agent.supply_chain_analyst.name
}

output "workflow_name" {
  description = "Name of the supply-chain scan workflow."
  value       = sg_workflow.supply_chain_scan.name
}

output "github_integration_name" {
  description = "Name of the GitHub Guild integration the agent uses."
  value       = local.resolved_github_integration_name
}
