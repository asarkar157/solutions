variable "model_names" {
  description = "Map of model keys to actual deployed model names"
  type = object({
    gpt4o         = string
    claude_sonnet = string
    gemini_flash  = string
  })
}

variable "policy_ids" {
  description = "Map of policy IDs to attach to the agents"
  type = object({
    dangerous_ops = string
  })
}

variable "integration_names" {
  description = <<-EOT
    Guild integration names attached to the terraform-module-manager agent.
    Both are required: GitHub for API access, Ubuntu CLI for git/tofu/terraform, tfsec/checkov, and gh against a real working tree.
    Provision `modules/aios-integration-ubuntu` and pass `integration_name` as `ubuntu_cli`.
  EOT
  type = object({
    github     = string
    ubuntu_cli = string
  })

  validation {
    condition     = trimspace(var.integration_names.github) != "" && trimspace(var.integration_names.ubuntu_cli) != ""
    error_message = "integration_names.github and integration_names.ubuntu_cli must be non-empty. The agent needs both Guild integrations; omitting ubuntu_cli (or passing \"\") leaves only GitHub tools and breaks terraform-module-compliance / install-validate-test SOPs."
  }
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "terraform-module-update::<stage_id>" where stage_id matches the workflow stage (e.g. analyze-request, security-scan-and-plan).
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}
