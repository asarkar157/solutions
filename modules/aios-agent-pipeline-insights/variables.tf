variable "model_names" {
  description = <<-EOT
    Ordered list of registered model names to expose to the agent (highest
    preference first). Forwarded straight to `sg_agent.model_names` after
    `compact()`.
  EOT
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
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
  description = <<-EOT
    Optional `sg_secret` ID holding the GitHub PAT (REST/GraphQL access for
    Actions, PRs, Deployments). When set (and `existing_github_integration_name`
    is empty), this module provisions an internal GitHub Guild integration. Set
    `existing_github_integration_name` instead to attach to a pre-provisioned
    tenant-level GitHub integration. One of the two must be provided.
  EOT
  type        = string
  default     = ""
}

variable "slack_secret_id" {
  description = <<-EOT
    Optional `sg_secret` ID for Slack workspace credentials. When set, this
    module provisions an internal Slack Guild integration so the agent can
    answer questions inside a Slack channel. Leave empty to skip Slack
    altogether (the workflow remains usable from Guild chat).
  EOT
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional Guild integration name to share an existing GitHub integration instead of provisioning one. When set, the module skips its own integration container."
  type        = string
  default     = ""
}

variable "existing_slack_integration_name" {
  description = "Optional Guild integration name to share an existing Slack integration. When set, the module skips its own integration container and `slack_secret_id` may be left empty."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / workflow / runbook / webhook / integration resource names so multiple instances can coexist in one Guild tenant."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "agent_budget" {
  description = "Daily $ budget for the pipeline-insights agent."
  type        = number
  default     = 8
}

variable "deployments_limit" {
  description = "Default number of recent deployments returned per environment when the operator does not supply a limit."
  type        = number
  default     = 10
}

variable "enable_slack_webhook" {
  description = <<-EOT
    Create an `sg_webhook` ingress (`target_type = workflow`) so a Slack app or
    other Slack-mention bridge can fire the pipeline-insights workflow with a
    raw question. Set to false if you only want to invoke the workflow from
    Guild chat or `aios-agent-schedules`.
  EOT
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Optional webhook ingress URLs (`POST /api/v1/webhooks/trigger`)
# ---------------------------------------------------------------------------
variable "webhook_trigger_base_url" {
  description = <<-EOT
    Optional StackGen HTTP API origin (e.g. `https://main.dev.stackgen.com`). When set,
    outputs include `webhook_trigger_endpoint` and, when the Slack-bridge webhook token
    exists, `webhook_ingress_payload_url` — a full URL with `apiKey=` for senders that
    cannot set `Authorization: Bearer`. Leave empty (default) to omit those outputs.
  EOT
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = <<-EOT
    Optional `orgId` query parameter appended to `webhook_ingress_payload_url` when
    `webhook_trigger_base_url` is set. Use the same StackGen organization / project id
    you pass as the provider `project_id` for this Guild tenant.
  EOT
  type        = string
  default     = ""
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
