output "agent_name" { value = sg_agent.gcp_sre.name }
output "policy_ids" { value = { gcp_tool_governance = sg_policy.gcp_tool_governance.id } }

output "gcp_integration_name" {
  description = "Name of the GCP Guild integration the agent uses."
  value       = local.resolved_gcp_integration_name
}
