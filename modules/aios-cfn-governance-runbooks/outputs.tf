output "runbook_names" {
  description = "Governance runbook SOP names keyed by use-case pillar."
  value = {
    remote_orchestration  = sg_runbook_sop.remote_orchestration.name
    contextual_compliance = sg_runbook_sop.contextual_compliance.name
    hardened_synthesis    = sg_runbook_sop.hardened_synthesis.name
    governed_deployment   = sg_runbook_sop.governed_deployment.name
    continuous_governance = sg_runbook_sop.continuous_governance.name
  }
}

output "runbook_names_list" {
  description = "All governance runbook SOP names for workflow runbook_refs."
  value = [
    sg_runbook_sop.remote_orchestration.name,
    sg_runbook_sop.contextual_compliance.name,
    sg_runbook_sop.hardened_synthesis.name,
    sg_runbook_sop.governed_deployment.name,
    sg_runbook_sop.continuous_governance.name,
  ]
}
