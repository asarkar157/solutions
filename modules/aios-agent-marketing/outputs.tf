output "agent_name" { value = sg_agent.marketing_ops.name }
output "workflow_names" {
  value = {
    content_pipeline   = sg_workflow.content_pipeline.name
    campaign_analytics = sg_workflow.campaign_analytics.name
  }
}
