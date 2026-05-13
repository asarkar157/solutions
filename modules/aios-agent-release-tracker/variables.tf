variable "model_names" {
  description = <<-EOT
    Ordered list of registered model names to expose to the agent (highest
    preference first). Forwarded straight to `sg_agent.model_names` after
    `compact()`.
  EOT
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Guardrail policy IDs. `dangerous_ops` is required."
  type = object({
    dangerous_ops = string
  })
}

variable "integration_names" {
  description = <<-EOT
    Map of integrations to attach to the release-tracker agent.
    Recognized keys (`github` is required; others optional):
      - github : GitHub integration name (REST/GraphQL access for tags, releases, packages)
      - slack  : Slack integration name (used for periodic digests)
  EOT
  type        = map(string)
}

variable "agent_budget" {
  description = "Daily $ budget for the release-tracker agent."
  type        = number
  default     = 5
}

variable "tag_limit" {
  description = "Default number of recent tags / image versions returned per repo when the operator does not supply a limit."
  type        = number
  default     = 10
}

variable "release_limit" {
  description = "Default number of GitHub Releases returned per repo when the operator does not supply a limit."
  type        = number
  default     = 5
}

variable "include_prereleases_default" {
  description = "Default value for the `include_prereleases` workflow input."
  type        = bool
  default     = false
}

variable "image_namespace_template" {
  description = <<-EOT
    Template used by the agent to derive a container image reference from a
    `service_name` when the operator does not supply `image` directly. Use
    `{{org}}` and `{{service}}` as placeholders. Example:
    `ghcr.io/appcd-dev/{{service}}`.
  EOT
  type        = string
  default     = "ghcr.io/{{org}}/{{service}}"
}

variable "service_catalog" {
  description = <<-EOT
    Optional map of `service_name` → repository (`owner/name`) used by the
    agent to resolve services to repos when the operator asks "what's the
    latest version of X?" without naming the repo. Empty map disables the
    catalog and forces the operator to pass `repository` directly.
  EOT
  type        = map(string)
  default     = {}
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
