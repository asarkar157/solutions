output "agent_name" { value = sg_agent.compliance_auditor.name }
output "policy_ids" { value = { compliance_data_access = sg_policy.compliance_data_access.id } }
