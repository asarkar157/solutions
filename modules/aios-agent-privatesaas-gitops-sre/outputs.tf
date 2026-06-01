output "agent_names" {
  description = "GitOps SRE agent names provisioned by this module."
  value = {
    intake       = sg_agent.slack_sre_intake.name
    investigator = sg_agent.gitops_sre_investigator.name
    remediator   = sg_agent.gitops_sre_remediator.name
  }
}

output "workflow_names" {
  value = {
    gitops_sre_incident_response = sg_workflow.gitops_sre_incident_response.name
    gitops_sre_quality_audit     = sg_workflow.gitops_sre_quality_audit.name
  }
}

output "gitlab_integration_name" {
  value = local.resolved_gitlab_integration_name
}

output "argocd_integration_name" {
  value = local.resolved_argocd_integration_name
}

output "sonarqube_integration_name" {
  value = local.resolved_sonarqube_integration_name
}

output "aws_integration_name" {
  value = local.resolved_aws_integration_name
}

output "slack_integration_name" {
  value = local.resolved_slack_integration_name
}

output "ubuntu_integration_name" {
  value = local.resolved_ubuntu_integration_name
}

output "evidence_checklist_name" {
  value = var.enable_evidence_checklist ? sg_evidence_checklist.gitops_sre_rca[0].name : ""
}

output "remote_runner_name" {
  value = length(module.remote_runner) > 0 ? module.remote_runner[0].runner_name : ""
}

output "remote_runner_created" {
  value = length(module.remote_runner) > 0 ? module.remote_runner[0].created : false
}

output "remote_runner_cli_start_command" {
  value     = length(module.remote_runner) > 0 ? module.remote_runner[0].cli_start_command : null
  sensitive = true
}

output "remote_runner_helm_install_command" {
  value     = length(module.remote_runner) > 0 ? module.remote_runner[0].helm_install_command : null
  sensitive = true
}

output "webhook_id" {
  value = var.enable_slack_webhook ? sg_webhook.slack_gitops_sre[0].id : ""
}

output "webhook_token" {
  value     = var.enable_slack_webhook ? sg_webhook.slack_gitops_sre[0].token : ""
  sensitive = true
}

output "webhook_trigger_endpoint" {
  value = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "webhook_ingress_payload_url" {
  sensitive = true
  value = (
    var.enable_slack_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.slack_gitops_sre[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.slack_gitops_sre[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
