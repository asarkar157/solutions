output "agent_name" {
  description = "Name of the CICD Overwatch investigator agent provisioned by this module."
  value       = sg_agent.investigator.name
}

output "workflow_name" {
  description = "Name of the cicd-overwatch-jenkins-rca workflow."
  value       = sg_workflow.cicd_overwatch_jenkins_rca.name
}

output "jenkins_integration_name" {
  description = "Resolved Jenkins Guild integration name."
  value       = nonsensitive(local.resolved_jenkins_integration_name)
}

output "linear_integration_name" {
  description = "Resolved Linear Guild integration name."
  value       = nonsensitive(local.resolved_linear_integration_name)
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name (empty string when not attached)."
  value       = nonsensitive(local.resolved_aws_integration_name)
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name (empty string when not attached)."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "knowledge_base_id" {
  description = "ID of the CICD Overwatch knowledge base when enable_knowledge_base is true; empty string otherwise."
  value       = var.enable_knowledge_base ? sg_knowledge_base.cicd_overwatch[0].id : ""
}

output "skill_names" {
  description = "Names of the Guild skills provisioned from this module's skills/ directory and referenced by workflow stages."
  value       = [for s in sg_skill.cicd_overwatch : s.name]
}

output "webhook_id" {
  description = "Linear ingress webhook id when enable_linear_webhook is true; empty string otherwise."
  value       = var.enable_linear_webhook ? sg_webhook.cicd_overwatch_linear_ticket_receiver[0].id : ""
}

output "webhook_token" {
  description = "Linear ingress webhook token when enable_linear_webhook is true."
  value       = var.enable_linear_webhook ? sg_webhook.cicd_overwatch_linear_ticket_receiver[0].token : ""
  sensitive   = true
}
