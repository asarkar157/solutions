output "agent_names" {
  description = "Marketing agent names for cross-module references"
  value = {
    content_strategist    = sg_agent.marketing_content.name
    pr_communications     = sg_agent.marketing_pr.name
    marketing_analyst     = sg_agent.marketing_analytics.name
    sales_enablement_lead = sg_agent.marketing_sales_enablement.name
  }
}

output "workflow_names" {
  value = {
    product_launch = sg_workflow.product_launch.name
  }
}
