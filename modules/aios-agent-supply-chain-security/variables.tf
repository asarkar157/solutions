variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
}
variable "policy_ids" {
  type = object({ dangerous_ops = string, sre_remediation = optional(string, "") })
}

variable "github_integration_name" {
  description = <<-EOT
    Guild GitHub integration name to attach (for example `module.github_integration.integration_name`).
    When empty and `github_token` is non-empty, the module attaches the legacy default name `github-integration`.
    Credentials live on the Guild integration / Vault secret — this module does not inject the token into agent runtime.
  EOT
  type        = string
  default     = ""
}

variable "github_token" {
  description = "Legacy gate only: when non-empty and `github_integration_name` is empty, attaches integration named `github-integration`. The token value is not passed to the agent."
  type        = string
  sensitive   = true
  default     = ""
}
variable "agent_budget" {
  type    = number
  default = 15
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow_name>::<stage_id>" where workflow_name is the sg_workflow.name in this module and stage_id matches the stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}

