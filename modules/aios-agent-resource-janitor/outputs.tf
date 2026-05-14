output "agent_name" {
  description = "Guild name of the resource-janitor agent."
  value       = sg_agent.resource_janitor.name
}

output "workflow_names" {
  description = "Workflow names exposed by this module. Use with aios-agent-schedules (target_type = \"workflow\")."
  value = {
    detection = sg_workflow.unused_resource_detection.name
    cleanup   = sg_workflow.unused_resource_cleanup.name
  }
}

output "runbook_names" {
  description = "Runbook SOP names registered by this module."
  value = {
    lambda_inactivity_scan     = sg_runbook_sop.lambda_inactivity_scan.name
    s3_stale_bucket_scan       = sg_runbook_sop.s3_stale_bucket_scan.name
    idle_compute_extended_scan = sg_runbook_sop.idle_compute_extended_scan.name
    safe_cleanup_procedure     = sg_runbook_sop.safe_cleanup_procedure.name
  }
}

output "evidence_checklist_name" {
  description = "Evidence checklist used by the destructive cleanup workflow."
  value       = sg_evidence_checklist.unused_resource_cleanup_evidence.name
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = local.resolved_aws_integration_name
}

output "azure_integration_name" {
  description = "Resolved Azure Guild integration name."
  value       = local.resolved_azure_integration_name
}

output "gcp_integration_name" {
  description = "Resolved GCP Guild integration name."
  value       = local.resolved_gcp_integration_name
}

output "slack_integration_name" {
  description = "Resolved Slack Guild integration name."
  value       = local.resolved_slack_integration_name
}
