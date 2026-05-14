output "agent_names" {
  description = "Registered agent names from this module"
  value = {
    repo_iac_architect = sg_agent.repo_iac_architect.name
  }
}

output "workflow_names" {
  description = "Workflow names for cross-module references"
  value = {
    repository_to_iac                = sg_workflow.repository_to_iac.name
    repo_scan_appstack_github_export = sg_workflow.repo_scan_appstack_github_export.name
  }
}

output "runbook_names" {
  description = "Runbook SOP names created for this workflow"
  value = {
    repository_discovery                 = sg_runbook_sop.repository_discovery.name
    stackgen_iac_synthesis               = sg_runbook_sop.stackgen_iac_synthesis.name
    deliverable_handoff                  = sg_runbook_sop.deliverable_handoff.name
    repo_appstack_infer_plan             = sg_runbook_sop.repo_appstack_infer_plan.name
    repo_appstack_provision_env          = sg_runbook_sop.repo_appstack_provision_env.name
    repo_appstack_artifact_export_github = sg_runbook_sop.repo_appstack_artifact_export_github.name
    stackgen_mcp_consumer_tool_catalog   = sg_runbook_sop.stackgen_mcp_consumer_tool_catalog.name
  }
}

output "github_integration_name" {
  description = "Name of the GitHub Guild integration the agent uses."
  value       = local.resolved_github_integration_name
}
