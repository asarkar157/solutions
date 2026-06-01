output "agent_names" {
  description = "Names of the self-hosted infra agents provisioned by this module."
  value = {
    event_ingest    = sg_agent.cfn_event_ingest.name
    investigator    = sg_agent.infra_investigator.name
    change_engineer = sg_agent.infra_change_engineer.name
  }
}

output "workflow_names" {
  description = "Workflow names provisioned by this module."
  value = {
    cloudformation_stack_incident    = sg_workflow.cloudformation_stack_incident.name
    cloudformation_drift_audit       = sg_workflow.cloudformation_drift_audit.name
    cloudformation_pre_deploy_review = sg_workflow.cloudformation_pre_deploy_review.name
  }
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = local.resolved_aws_integration_name
}

output "ubuntu_integration_name" {
  description = "Resolved Ubuntu CLI integration name when enable_ubuntu_cli or create_remote_runner is true; empty string otherwise."
  value       = local.resolved_ubuntu_integration_name
}

output "evidence_checklist_name" {
  description = "Evidence checklist name when enable_evidence_checklist is true; empty string otherwise."
  value       = var.enable_evidence_checklist ? sg_evidence_checklist.selfhosted_infra_rca[0].name : ""
}

output "remote_runner_name" {
  description = "Remote runner name when remote_runner submodule is instantiated; empty string otherwise."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].runner_name : ""
}

output "remote_runner_created" {
  description = "Whether the remote runner resource was created."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].created : false
}

output "remote_runner_cli_start_command" {
  description = "aiden-runner CLI start command when remote runner submodule is present."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].cli_start_command : null
  sensitive   = true
}

output "remote_runner_helm_install_command" {
  description = "Helm install command for aiden-runner when remote runner submodule is present."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].helm_install_command : null
  sensitive   = true
}

output "webhook_id" {
  description = "CloudFormation failure ingress webhook id when enable_stack_failure_webhook is true; empty string otherwise."
  value       = var.enable_stack_failure_webhook ? sg_webhook.cloudformation_stack_failure[0].id : ""
}

output "webhook_token" {
  description = "CloudFormation failure ingress webhook token when enable_stack_failure_webhook is true."
  value       = var.enable_stack_failure_webhook ? sg_webhook.cloudformation_stack_failure[0].token : ""
  sensitive   = true
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive `POST …/api/v1/webhooks/trigger` URL when `webhook_trigger_base_url` is set; empty string otherwise."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with `apiKey` when `webhook_trigger_base_url` is set and the webhook token is non-empty; null otherwise."
  sensitive   = true
  value = (
    var.enable_stack_failure_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.cloudformation_stack_failure[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.cloudformation_stack_failure[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
