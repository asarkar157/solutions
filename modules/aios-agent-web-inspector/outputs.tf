output "agent_name" {
  description = "Name of the Web Inspector agent."
  value       = sg_agent.web_inspector.name
}

output "chrome_integration_name" {
  description = "Resolved Chrome integration name."
  value       = nonsensitive(local.resolved_chrome)
}

output "ubuntu_integration_name" {
  description = "Resolved Ubuntu CLI integration name."
  value       = nonsensitive(local.resolved_ubuntu)
}

output "runbook_sop_names" {
  description = "Names of the Web Inspector SOPs."
  value = {
    visual_smoke_test          = sg_runbook_sop.visual_smoke_test.name
    frontend_performance_audit = sg_runbook_sop.frontend_performance_audit.name
    cross_signal_triage        = sg_runbook_sop.cross_signal_triage.name
  }
}
