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

# =============================================================================
# Self-contained integration wiring (replaces the old `integration_names` map).
# =============================================================================

variable "github_secret_id" {
  description = "Optional `sg_secret` ID for the GitHub PAT. When set (and `existing_github_integration_name` is empty), this module provisions an internal GitHub Guild integration. One of `github_secret_id` / `existing_github_integration_name` must be provided."
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = "Optional `sg_secret` ID for Slack workspace credentials. When set, this module provisions an internal Slack Guild integration so the agent can post periodic digests / reply to questions in Slack."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration instead of provisioning one."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional Guild integration name to share an existing Slack integration."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / workflow / runbook / integration resource names so multiple instances can coexist in one Guild tenant."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
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

variable "enable_stackgen_deployment_catalog" {
  description = <<-EOT
    When true, loads configured Guild deployment-catalog applications at plan
    time via `data.sg_apps` (`installation = "configured"`) and surfaces app
    names in the deployed-version runbook for optional cross-check against
    GitHub deployments. Each catalog app exposes `integrations` (list of bound
    Guild integration names). Requires StackGen provider >= 0.1.25 and provider
    `project_id` / `org_id` when the catalog is org-scoped.
  EOT
  type        = bool
  default     = false
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
