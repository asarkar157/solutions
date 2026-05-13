output "next_steps" {
  description = "Copy-paste prompt to open Guild and start the demo."
  value       = <<-EOT

    Demo ready. Next steps:
      1. Open Guild:        ${var.stackgen_url}
      2. Find agent:        ${module.aws_sre.aws_sre_agent_name}
      3. Try this prompt:   "An EC2 instance in ${var.aws_region} is unhealthy. Triage and propose a fix."

  EOT
}

output "aws_sre_agent_name" {
  description = "Guild agent registered by this scenario."
  value       = module.aws_sre.aws_sre_agent_name
}

output "aws_integration_name" {
  description = "Guild integration the AWS-SRE agent is wired to."
  value       = module.aws_integration.integration_name
}

output "slack_enabled" {
  description = "Whether the Slack integration was created (depends on slack_bot_token)."
  value       = length(module.slack_integration) > 0
}
