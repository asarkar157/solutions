output "agent_names" {
  description = "Names of the agents created in this module."
  value = {
    scenario_author = sg_agent.scenario_author.name
  }
}

output "workflow_name" {
  description = "Guild workflow name (input to e.g. `aios-agent-schedules` if you want to invoke it on a cron)."
  value       = sg_workflow.scenario_request_triage.name
}

output "runbook_sop_names" {
  description = "Names of the four runbook SOPs this module registers; useful when composing with other agents that want to reference them via `runbook_refs`."
  value = {
    orchestration = sg_runbook_sop.scenario_author_orchestration.name
    triage        = sg_runbook_sop.scenario_triage.name
    scaffold      = sg_runbook_sop.scenario_scaffold.name
    pr_and_notify = sg_runbook_sop.scenario_pr_and_notify.name
  }
}

output "github_integration_name" {
  description = <<-EOT
    Final Guild name of the GitHub integration the agent attaches to. Equals the
    consumer-supplied `existing_github_integration_name` when set, otherwise the
    module-prefixed name `scenario-author-github[-<name_suffix>]` produced by the
    internal `module.github_integration[0]`. Use this when composing the same
    integration across multiple agent modules via `existing_*_integration_name`
    overrides to dedupe containers.
  EOT
  value       = local.resolved_github_integration_name
}

output "ubuntu_integration_name" {
  description = <<-EOT
    Final Guild name of the Ubuntu CLI integration the agent attaches to. Equals
    the consumer-supplied `existing_ubuntu_integration_name` when set, otherwise
    the module-prefixed name `scenario-author-ubuntu[-<name_suffix>]` produced by
    the internal `module.ubuntu_integration[0]`.
  EOT
  value       = local.resolved_ubuntu_integration_name
}

output "webhook_id" {
  description = "ID of the GitHub webhook ingress. Configure GitHub to POST `issue` events here. Empty when `enable_webhook = false`."
  value       = try(sg_webhook.github_scenario_request[0].id, "")
}

output "webhook_token" {
  description = "Secret token for the GitHub webhook ingress. Use it as the GitHub webhook's `Secret` field. Empty when `enable_webhook = false`."
  value       = try(sg_webhook.github_scenario_request[0].token, "")
  sensitive   = true
}
