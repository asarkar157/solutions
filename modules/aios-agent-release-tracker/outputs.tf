output "agent_name" {
  description = "Guild name of the release-tracker agent."
  value       = sg_agent.release_tracker.name
}

output "workflow_name" {
  description = "Name of the microservice-release-tracking workflow. Pass to aios-agent-schedules with target_type = \"workflow\" for periodic release digests."
  value       = sg_workflow.release_tracking.name
}

output "runbook_names" {
  description = "Runbook SOP names registered by this module."
  value = {
    latest_tags_and_releases      = sg_runbook_sop.latest_tags_and_releases.name
    container_image_tag_discovery = sg_runbook_sop.container_image_tag_discovery.name
    deployed_version_correlation  = sg_runbook_sop.deployed_version_correlation.name
    release_diff                  = sg_runbook_sop.release_diff.name
  }
}

output "github_integration_name" {
  description = "Name of the GitHub Guild integration the agent uses."
  value       = local.resolved_github_integration_name
}

output "slack_integration_name" {
  description = "Name of the Slack Guild integration the agent uses, or empty string when no Slack integration is wired."
  value       = local.resolved_slack_integration_name
}
