output "next_steps" {
  description = "Copy-paste prompt to open Guild and start the demo."
  value       = <<-EOT

    Demo ready. Next steps:
      1. Open Guild:        ${var.stackgen_url}
      2. Find agent:        ${sg_agent.jenkins_sre.name}
      3. Try this prompt:   "Show me the available pipelines in Jenkins."
      4. Try triggering a non-prod build: "Trigger the staging-smoke-tests pipeline."
      5. Try triggering a prod build:     "Trigger the production-deploy pipeline."

  EOT
}

output "agent_name" {
  description = "Guild agent registered by this scenario."
  value       = sg_agent.jenkins_sre.name
}

output "integration_name" {
  description = "Guild integration the Jenkins-SRE agent is wired to."
  value       = module.jenkins_integration.integration_name
}

output "slack_enabled" {
  description = "Whether the Slack integration was created (depends on slack_bot_token)."
  value       = length(module.slack_integration) > 0
}
