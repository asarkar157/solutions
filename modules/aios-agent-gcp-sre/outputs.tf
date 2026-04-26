output "agent_name" { value = sg_agent.gcp_sre.name }
output "policy_ids" { value = { gcp_tool_governance = sg_policy.gcp_tool_governance.id } }
