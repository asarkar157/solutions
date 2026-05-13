output "next_steps" {
  description = "Copy-paste prompt to open Guild and start the demo."
  value       = <<-EOT

    Demo ready. Next steps:
      1. Open Guild:                ${var.stackgen_url}
      2. FinOps agent:              ${module.cost_optimizer.agent_name}
      3. Janitor agent:             ${module.resource_janitor.agent_name}
      4. Try in chat:               "Summarize the top 5 cost anomalies in the connected AWS account and propose savings."
      5. Show the schedules:        weekly-finops-review (Mon 09:00 UTC), weekly-unused-resource-sweep (Mon 08:00 UTC).

  EOT
}

output "cost_optimizer_agent_name" {
  value = module.cost_optimizer.agent_name
}

output "resource_janitor_agent_name" {
  value = module.resource_janitor.agent_name
}

output "cost_optimizer_workflow_name" {
  value = module.cost_optimizer.workflow_name
}

output "resource_janitor_workflow_names" {
  value = module.resource_janitor.workflow_names
}
