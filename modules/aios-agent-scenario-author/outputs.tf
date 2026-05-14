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
  description = <<-EOT
    Names of the three runbook SOPs this module registers; useful when composing with
    other agents that want to reference them via `runbook_refs`. The map shape changed
    in the Cursor refactor (the old `triage` + `scaffold` keys were collapsed into the
    single `cursor_author` SOP that drives `cursor_agents_run_task`).
  EOT
  value = {
    orchestration = sg_runbook_sop.scenario_author_orchestration.name
    cursor_author = sg_runbook_sop.scenario_cursor_author.name
    pr_and_notify = sg_runbook_sop.scenario_pr_and_notify.name
  }
}

output "github_integration_name" {
  description = <<-EOT
    Final Guild name of the GitHub integration the agent attaches to. Equals the
    consumer-supplied `existing_github_integration_name` when set, otherwise the
    module-prefixed name `scenario-author-github[-<name_suffix>]` produced by the
    internal `module.github_integration[0]`. Used by the planner for `gh api` reads
    of the triggering issue and `gh issue comment` replies.
  EOT
  value       = local.resolved_github_integration_name
}

output "cursor_integration_name" {
  description = <<-EOT
    Final Guild name of the Cursor MCP integration the agent attaches to. Equals
    the consumer-supplied `existing_cursor_integration_name` when set, otherwise
    the module-prefixed name `scenario-author-cursor[-<name_suffix>]` produced by
    the internal `module.cursor_integration[0]`. Exposes the `cursor_agents_*`
    tools (notably `cursor_agents_run_task`) the planner uses to delegate the
    repo clone, scaffold, and PR creation to a Cursor Cloud Agent.
  EOT
  value       = local.resolved_cursor_integration_name
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
