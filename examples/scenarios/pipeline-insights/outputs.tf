output "next_steps" {
  description = "Copy-paste prompt to open Guild and start the demo."
  value       = <<-EOT

    Demo ready. Next steps:
      1. Open Guild:                ${var.stackgen_url}
      2. Pipeline-insights agent:   ${module.pipeline_insights.agent_name}
      3. Release-tracker agent:     ${module.release_tracker.agent_name}
      4. Try this prompt:           "Show me the last 5 deployments to production and the PRs that drove them."
      5. Or, for releases:          "What's the latest tag on appcd-dev/solutions and is it the version we're running?"

  EOT
}

output "pipeline_insights_agent_name" {
  value = module.pipeline_insights.agent_name
}

output "release_tracker_agent_name" {
  value = module.release_tracker.agent_name
}

output "pipeline_insights_workflow_name" {
  value = module.pipeline_insights.workflow_name
}

output "release_tracker_workflow_name" {
  value = module.release_tracker.workflow_name
}

output "slack_enabled" {
  value = length(module.slack_integration) > 0
}
