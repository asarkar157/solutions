output "cfn_author" {
  description = "Full cfn-author module outputs."
  value = {
    agent_names                            = module.cfn_author.agent_names
    workflow_names                         = module.cfn_author.workflow_names
    governance_runbook_names               = module.cfn_author.governance_runbook_names
    recommended_skill_names                = module.cfn_author.recommended_skill_names
    workspace                              = module.cfn_author.workspace
    intent_webhook_ingress_payload_url     = module.cfn_author.intent_webhook_ingress_payload_url
    compliance_webhook_ingress_payload_url = module.cfn_author.compliance_webhook_ingress_payload_url
    drift_webhook_ingress_payload_url      = module.cfn_author.drift_webhook_ingress_payload_url
  }
  sensitive = true
}

output "terraform_bot" {
  description = "Terraform bot outputs when enable_terraform_bot is true; null otherwise."
  value = var.enable_terraform_bot ? {
    agent_names            = module.terraform_bot[0].agent_names
    workflow_name          = module.terraform_bot[0].workflow_name
    iam_gate_workflow_name = module.terraform_bot[0].iam_gate_workflow_name
  } : null
}

output "aiden_infra_workflow_names" {
  description = "Merged workflow names across CFN author and optional terraform-bot."
  value = merge(
    module.cfn_author.workflow_names,
    var.enable_terraform_bot ? {
      terraform_module_update = module.terraform_bot[0].workflow_name
      pre_deploy_iam_review   = module.terraform_bot[0].iam_gate_workflow_name
    } : {},
  )
}

output "webhook_trigger_endpoint" {
  description = "Guild POST /api/v1/webhooks/trigger base URL."
  value       = module.cfn_author.webhook_trigger_endpoint
}
