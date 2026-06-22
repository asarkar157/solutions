locals {
  demo_prompt = local.enable_aws ? "An EC2 instance in ${var.aws_region} is unhealthy. Use AWS tools, check related GitHub deploys, and propose a fix." : "What shipped recently on GitHub for our main service? Summarize recent deploys and open PRs."

  next_steps_with_runner = <<-EOT

    SRE boost ready. Next steps:
      1. Open Guild:              ${var.stackgen_url}
      2. Agent:                   ${sg_agent.sre_boost.name}
      3. Start remote runner:     ${module.remote_runner.runner_name} must show online before shell tools work
         Helm:   tofu output -raw remote_runner_helm_install_command
         Docker: tofu output -raw remote_runner_docker_run_command
         (or both): tofu output -raw remote_runner_start_commands
      4. Try this prompt:         "${local.demo_prompt}"

  EOT

  next_steps_without_runner = <<-EOT

    SRE boost ready. Next steps:
      1. Open Guild:              ${var.stackgen_url}
      2. Agent:                   ${sg_agent.sre_boost.name}
      3. Try this prompt:         "${local.demo_prompt}"

  EOT

  remote_runner_start_commands_body = <<-EOT
# Helm (Kubernetes)
${module.remote_runner.helm_install_command}

# Docker
${local.remote_runner_docker_run_command}
EOT
}

output "next_steps" {
  description = "Copy-paste steps to finish the demo after apply."
  value       = var.create_remote_runner ? local.next_steps_with_runner : local.next_steps_without_runner
}

output "agent_name" {
  description = "Existing Guild agent with AWS, GitHub, and optional remote runner attached."
  value       = sg_agent.sre_boost.name
}

output "model_names" {
  description = "Model names preserved from the existing agent (unchanged by this root)."
  value       = data.sg_agent.target.model_names
}

output "aws_integration_name" {
  value = local.enable_aws ? module.aws_integration[0].integration_name : null
}

output "aws_role_arn" {
  description = "Customer IAM role ARN wired into the AWS integration, when aws_role_arn was set."
  value       = local.enable_aws ? var.aws_role_arn : null
}

output "aws_vault_trust_policy" {
  description = "Workspace trust policy JSON — use when fixing ASSUME_ROLE_TRUST_DENIED on an existing role."
  value       = data.sg_vault_aws_config.workspace.trust_policy
  sensitive   = true
}

output "github_integration_name" {
  value = module.github_integration.integration_name
}

output "ubuntu_integration_name" {
  description = "Ubuntu CLI integration with kubectl when enable_ubuntu_kubectl is true."
  value       = var.enable_ubuntu_kubectl ? module.ubuntu_integration[0].integration_name : null
}

output "remote_runner_name" {
  value = module.remote_runner.runner_name
}

output "remote_runner_start_commands" {
  description = "Copy-paste Helm and Docker commands to start the remote runner when create_remote_runner is true."
  value       = var.create_remote_runner ? local.remote_runner_start_commands_body : ""
  sensitive   = true
}

output "remote_runner_helm_install_command" {
  description = "Helm install command for aiden-runner when create_remote_runner is true."
  value       = var.create_remote_runner ? module.remote_runner.helm_install_command : null
  sensitive   = true
}

output "remote_runner_docker_run_command" {
  description = "Docker run command for aiden-runner when create_remote_runner is true."
  value       = var.create_remote_runner ? local.remote_runner_docker_run_command : null
  sensitive   = true
}

output "remote_runner_cli_start_command_with_secrets" {
  description = "Bare-metal aiden-runner start command (CLI) when create_remote_runner is true."
  value       = var.create_remote_runner ? module.remote_runner.cli_start_command_with_secrets : null
  sensitive   = true
}
