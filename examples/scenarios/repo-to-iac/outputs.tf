output "next_steps" {
  description = "Copy-paste prompt to open Guild and start the demo."
  value       = <<-EOT

    Demo ready. Next steps:
      1. Open Guild:                ${var.stackgen_url}
      2. Agent:                     ${module.repo_to_iac.agent_names.repo_iac_architect}
      3. Workflow to run:           ${module.repo_to_iac.workflow_names.repository_to_iac}
      4. Try with the demo repo:    "Run the repository-to-iac workflow against ${var.github_repo_url != "" ? var.github_repo_url : "<paste a GitHub URL>"} and show me the generated IaC."

  EOT
}

output "agent_names" {
  value = module.repo_to_iac.agent_names
}

output "workflow_names" {
  value = module.repo_to_iac.workflow_names
}
