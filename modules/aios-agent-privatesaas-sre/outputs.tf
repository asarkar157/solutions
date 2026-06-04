output "agent_names" {
  description = "Names of the PrivateSaaS SRE agents provisioned by this module."
  value = {
    incident_ingest     = sg_agent.incident_ingest.name
    investigator        = sg_agent.privatesaas_sre_investigator.name
    runbook_coordinator = sg_agent.runbook_coordinator.name
  }
}

output "workflow_names" {
  description = "Workflow names provisioned by this module."
  value = {
    privatesaas_incident_response = sg_workflow.privatesaas_incident_response.name
    privatesaas_runbook_audit     = sg_workflow.privatesaas_runbook_audit.name
  }
}

output "runbook_names" {
  description = "Generic module runbook SOP names (multi-source library)."
  value = {
    generic_triage          = sg_runbook_sop.generic_triage.name
    generic_gcp             = sg_runbook_sop.generic_gcp.name
    generic_runbook_routing = sg_runbook_sop.generic_runbook_routing.name
  }
}

output "grafana_integration_name" {
  value = nonsensitive(local.resolved_grafana_integration_name)
}

output "gcp_integration_name" {
  value = nonsensitive(local.resolved_gcp_integration_name)
}

output "firehydrant_integration_name" {
  value = nonsensitive(local.resolved_firehydrant_integration_name)
}

output "internal_tool_integration_name" {
  value = nonsensitive(local.resolved_internal_tool_integration_name)
}

output "grafana_webhook_id" {
  description = "Grafana ingress webhook id when enable_grafana_webhook is true."
  value       = var.enable_grafana_webhook ? sg_webhook.grafana_privatesaas_sre[0].id : ""
}

output "grafana_webhook_token" {
  description = "Grafana ingress webhook token when enable_grafana_webhook is true."
  value       = var.enable_grafana_webhook ? sg_webhook.grafana_privatesaas_sre[0].token : ""
  sensitive   = true
}

output "firehydrant_webhook_id" {
  description = "FireHydrant ingress webhook id when enable_firehydrant_webhook is true."
  value       = var.enable_firehydrant_webhook ? sg_webhook.firehydrant_privatesaas_sre[0].id : ""
}

output "firehydrant_webhook_token" {
  description = "FireHydrant ingress webhook token when enable_firehydrant_webhook is true."
  value       = var.enable_firehydrant_webhook ? sg_webhook.firehydrant_privatesaas_sre[0].token : ""
  sensitive   = true
}

output "webhook_trigger_endpoint" {
  description = "Non-sensitive trigger URL when webhook_trigger_base_url is set."
  value       = trimspace(var.webhook_trigger_base_url) == "" ? "" : "${trimsuffix(trimspace(var.webhook_trigger_base_url), "/")}/api/v1/webhooks/trigger"
}

output "grafana_webhook_ingress_payload_url" {
  description = "Full Grafana webhook trigger URL with apiKey when configured."
  sensitive   = true
  value = (
    var.enable_grafana_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.grafana_privatesaas_sre[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.grafana_privatesaas_sre[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}

output "firehydrant_webhook_ingress_payload_url" {
  description = "Full FireHydrant webhook trigger URL with apiKey when configured."
  sensitive   = true
  value = (
    var.enable_firehydrant_webhook
    && trimspace(var.webhook_trigger_base_url) != ""
    && trimspace(sg_webhook.firehydrant_privatesaas_sre[0].token) != ""
    ) ? format(
    "%s/api/v1/webhooks/trigger?apiKey=%s%s",
    trimsuffix(trimspace(var.webhook_trigger_base_url), "/"),
    urlencode(sg_webhook.firehydrant_privatesaas_sre[0].token),
    trimspace(var.webhook_trigger_org_id) == "" ? "" : format("&orgId=%s", urlencode(trimspace(var.webhook_trigger_org_id)))
  ) : null
}
