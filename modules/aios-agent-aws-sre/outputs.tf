output "aws_sre_agent_name" { value = sg_agent.aws_sre.name }
output "policy_ids" { value = { aws_tool_governance = sg_policy.aws_tool_governance.id } }

output "aws_integration_name" {
  description = "Name of the AWS Guild integration the agent uses."
  value       = local.resolved_aws_integration_name
}
