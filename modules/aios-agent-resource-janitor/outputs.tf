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
