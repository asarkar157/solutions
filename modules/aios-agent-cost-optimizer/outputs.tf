output "agent_name" { value = sg_agent.cost_optimizer.name }

output "workflow_name" {
  description = "Name of the finops-review workflow. Pass to aios-agent-schedules with target_type = \"workflow\" for periodic FinOps reports."
  value       = sg_workflow.finops_review.name
}
