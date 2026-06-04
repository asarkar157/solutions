output "agent_name" { value = sg_agent.compliance_auditor.name }
output "policy_ids" { value = { compliance_data_access = sg_policy.compliance_data_access.id } }

output "compliance_evidence_factory_workflow_name" {
  description = "Name of compliance-evidence-factory workflow when enable_compliance_evidence_factory is true."
  value       = local.evidence_factory_enabled ? sg_workflow.compliance_evidence_factory[0].name : ""
}

output "workflow_name" {
  description = "Name of the compliance-assessment workflow."
  value       = sg_workflow.compliance_assessment.name
}

output "runbook_sop_names" {
  description = "Names of the compliance-auditor runbook SOPs."
  value = {
    soc2_access_review     = sg_runbook_sop.soc2_access_review.name
    soc2_change_management = sg_runbook_sop.soc2_change_management.name
    gdpr_data_mapping      = sg_runbook_sop.gdpr_data_mapping.name
    audit_log_analysis     = sg_runbook_sop.audit_log_analysis.name
  }
}

output "evidence_checklist_name" {
  description = "Name of the compliance-assessment evidence checklist."
  value       = sg_evidence_checklist.compliance_assessment_evidence.name
}

output "aws_integration_name" {
  description = "Resolved AWS Guild integration name."
  value       = nonsensitive(local.resolved_aws_integration_name)
}

output "github_integration_name" {
  description = "Resolved GitHub Guild integration name."
  value       = nonsensitive(local.resolved_github_integration_name)
}
