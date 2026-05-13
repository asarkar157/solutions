variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
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

variable "remote_runner_name" {
  description = <<-EOT
    Optional Guild remote runner name (`runner_id`). When `remote_runner_attach_to_agent` is true, the module
    looks it up with `data.sg_remote_runner` and sets `remote_runners` on the agent (provider **>= 0.1.13**).
    Use for heavy `terraform`/`tofu` work off the default MCP sandbox when your org provisions runners.
  EOT
  type        = string
  default     = ""
}

variable "remote_runner_attach_to_agent" {
  description = <<-EOT
    When true, attaches `remote_runner_name` to the agent via `sg_agent.remote_runners`. Requires a non-empty
    `remote_runner_name` and provider org scope when the Guild API requires it.
  EOT
  type        = bool
  default     = false

  validation {
    condition     = !var.remote_runner_attach_to_agent || trimspace(var.remote_runner_name) != ""
    error_message = "remote_runner_attach_to_agent requires a non-empty remote_runner_name."
  }
}
