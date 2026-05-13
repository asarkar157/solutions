output "tenant_snapshot" {
  description = <<-EOT
    Read-only snapshot of the configured StackGen tenant. Consumed by
    emit-hcl.py to produce HCL stubs. The shape is best-effort and uses try()
    on each provider attribute so a missing field (different provider version)
    yields a null in the JSON rather than aborting the apply.
  EOT
  value = {
    captured_at         = timestamp()
    stackgen_url        = var.stackgen_url
    stackgen_project_id = var.stackgen_project_id
    me = {
      id    = try(data.sg_me.current.id, null)
      email = try(data.sg_me.current.email, null)
      name  = try(data.sg_me.current.name, null)
    }
    agents         = try(data.sg_agents.all.agents, [])
    workflows      = try(data.sg_workflows.all.workflows, [])
    remote_runners = try(data.sg_remote_runners.all.runners, [])
  }
}

output "agent_count" {
  description = "Number of agents in the snapshot. Use for a quick sanity check before consuming tenant_snapshot."
  value       = length(try(data.sg_agents.all.agents, []))
}

output "workflow_count" {
  description = "Number of workflows in the snapshot."
  value       = length(try(data.sg_workflows.all.workflows, []))
}

output "remote_runner_count" {
  description = "Number of remote runners in the snapshot."
  value       = length(try(data.sg_remote_runners.all.runners, []))
}
