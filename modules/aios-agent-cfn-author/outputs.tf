output "agent_names" {
  description = "CFN author agents provisioned by this module."
  value = {
    cfn_author        = sg_agent.cfn_author.name
    cfn_drift_manager = sg_agent.cfn_drift_manager.name
  }
}

output "workflow_names" {
  description = "Workflow names provisioned by this module."
  value = merge(
    {
      intent_to_infrastructure        = sg_workflow.intent_to_infrastructure.name
      cloudformation_drift_management = sg_workflow.cloudformation_drift_management.name
    },
    var.enable_contextual_compliance_workflow ? {
      contextual_compliance = sg_workflow.contextual_compliance[0].name
    } : {},
    var.enable_governed_deployment_workflow ? {
      governed_deployment = sg_workflow.governed_deployment[0].name
    } : {},
  )
}

output "governance_runbook_names" {
  description = "Reusable governance runbook SOP names from aios-cfn-governance-runbooks."
  value       = module.governance_runbooks.runbook_names
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = nonsensitive(local.resolved_github_integration_name)
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = nonsensitive(local.resolved_aws_integration_name)
}

output "ubuntu_integration_name" {
  description = "Resolved Ubuntu CLI integration name when enabled."
  value       = nonsensitive(local.resolved_ubuntu_integration_name)
}

output "evidence_checklist_names" {
  description = "Evidence checklist names when enable_evidence_checklist is true."
  value = var.enable_evidence_checklist ? {
    intent_to_infrastructure        = sg_evidence_checklist.intent_to_infrastructure[0].name
    cloudformation_drift_management = sg_evidence_checklist.drift_management[0].name
  } : {}
}

output "remote_runner_name" {
  description = "Remote runner name when configured."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].runner_name : ""
}

output "remote_runner_cli_start_command" {
  description = "aiden-runner CLI start command when remote runner is configured."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].cli_start_command : null
  sensitive   = true
}

output "remote_runner_helm_install_command" {
  description = "Helm install command for aiden-runner when remote runner is configured."
  value       = length(module.remote_runner) > 0 ? module.remote_runner[0].helm_install_command : null
  sensitive   = true
}

output "drift_schedule_names" {
  description = "Cron schedule names when enable_drift_schedule is true."
  value       = var.enable_drift_schedule ? module.drift_schedule[0].schedule_names : []
}

output "recommended_skill_names" {
  description = "Guild skill names referenced by workflow stage_bindings. Markdown sources live under module skills/ — sync via Guild skill source."
  value = [
    "cfn-developer-intent-handler",
    "cfn-company-best-practices",
    "cfn-template-catalog-discovery",
    "cfn-architecture-fit-review",
    "cfn-drift-scan-orchestration",
    "cfn-drift-risk-classifier",
    "cfn-drift-incorporate-pr",
  ]
}

output "intent_webhook_id" {
  description = "Intent-to-infrastructure webhook id when enable_intent_webhook is true; empty string otherwise."
  value       = var.enable_intent_webhook ? sg_webhook.intent_to_infrastructure[0].id : ""
}

output "intent_webhook_token" {
  description = "Intent-to-infrastructure webhook token when enable_intent_webhook is true."
  value       = var.enable_intent_webhook ? sg_webhook.intent_to_infrastructure[0].token : ""
  sensitive   = true
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive POST …/api/v1/webhooks/trigger URL when webhook_trigger_base_url is set."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "compliance_webhook_id" {
  description = "Contextual-compliance webhook id when enable_compliance_webhook is true; empty otherwise."
  value = (
    var.enable_contextual_compliance_workflow && var.enable_compliance_webhook
  ) ? sg_webhook.contextual_compliance[0].id : ""
}

output "compliance_webhook_token" {
  description = "Contextual-compliance webhook token when enable_compliance_webhook is true."
  value = (
    var.enable_contextual_compliance_workflow && var.enable_compliance_webhook
  ) ? sg_webhook.contextual_compliance[0].token : ""
  sensitive = true
}

output "compliance_webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with apiKey for compliance webhook when webhook_trigger_base_url is set."
  sensitive   = true
  value = (
    var.enable_contextual_compliance_workflow
    && var.enable_compliance_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.contextual_compliance[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.contextual_compliance[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "intent_webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with apiKey when webhook_trigger_base_url is set and enable_intent_webhook produced a token; null otherwise."
  sensitive   = true
  value = (
    var.enable_intent_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.intent_to_infrastructure[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.intent_to_infrastructure[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "workspace" {
  description = "Resolved default workspace binding used by workflows and runbooks."
  value       = local.resolved_workspace
}

output "drift_webhook_id" {
  description = "Drift management webhook id when enable_drift_webhook is true; empty otherwise."
  value       = var.enable_drift_webhook ? sg_webhook.drift_management[0].id : ""
}

output "drift_webhook_token" {
  description = "Drift management webhook token when enable_drift_webhook is true."
  value       = var.enable_drift_webhook ? sg_webhook.drift_management[0].token : ""
  sensitive   = true
}

output "drift_webhook_ingress_payload_url" {
  description = "Full StackGen trigger URL with apiKey for drift webhook when webhook_trigger_base_url is set."
  sensitive   = true
  value = (
    var.enable_drift_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.drift_management[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.drift_management[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "script_pack_version" {
  description = "Embedded Ubuntu script pack version — recycle cfn-author Ubuntu sidecar after tofu apply when this changes."
  value       = local.script_pack_version
}
