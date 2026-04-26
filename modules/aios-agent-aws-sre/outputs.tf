output "aws_sre_agent_name" { value = sg_agent.aws_sre.name }
output "policy_ids" { value = { aws_tool_governance = sg_policy.aws_tool_governance.id } }
