output "agent_name" { value = sg_agent.ubuntu_cli_agent.name }

output "ubuntu_integration_name" {
  description = "Resolved Ubuntu CLI Guild integration name."
  value       = local.resolved_ubuntu_integration_name
}

output "runbook_sop_names" {
  description = "Names of the Ubuntu CLI inspector SOPs."
  value = {
    network_diagnostics = sg_runbook_sop.ubuntu_network_diagnostics.name
    process_triage      = sg_runbook_sop.ubuntu_process_triage.name
    disk_triage         = sg_runbook_sop.ubuntu_disk_triage.name
    log_analysis        = sg_runbook_sop.ubuntu_log_analysis.name
  }
}
