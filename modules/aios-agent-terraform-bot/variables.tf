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

variable "github_secret_id" {
  description = <<-EOT
    ID of a pre-existing `sg_secret` holding the GitHub PAT this bot uses to clone target
    repositories, run `gh pr create`, comment on PRs, and call `gh api`. The same secret is
    bound to BOTH integrations this module provisions internally:
      - the `terraform-bot-github` Guild integration (for `gh api` calls from the API
        sandbox), and
      - the `terraform-bot-ubuntu` Guild integration (so `gh auth status` / `git clone` /
        `tofu`/`terraform` Just Work inside the shell sandbox without the agent threading
        a token through subagent goals).

    Required. Recommended PAT scopes: `repo`, `read:org`. Pass `sg_secret.<name>.id`. Use the
    same secret across multiple agent modules to keep ONE PAT in Vault per tenant.
  EOT
  type        = string

  validation {
    condition     = trimspace(var.github_secret_id) != ""
    error_message = "github_secret_id is required; the terraform-bot cannot clone repos or open PRs without it."
  }
}

variable "existing_github_integration_name" {
  description = <<-EOT
    Optional. When set, this module SKIPS provisioning its own `terraform-bot-github`
    Guild integration and attaches the agent to the supplied existing integration
    name instead. Default `""` keeps the self-contained behaviour.
  EOT
  type        = string
  default     = ""
}

variable "existing_ubuntu_integration_name" {
  description = <<-EOT
    Optional. When set, this module SKIPS provisioning its own `terraform-bot-ubuntu`
    Guild integration and attaches the agent to the supplied existing integration
    name instead. Note: the existing Ubuntu container must already have the GitHub PAT
    surfaced as `GH_TOKEN` (otherwise `gh` / `git clone` will fail inside the sandbox).
    Default `""` keeps the self-contained behaviour.
  EOT
  type        = string
  default     = ""
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

variable "name_suffix" {
  description = <<-EOT
    Optional suffix appended (with a leading `-`) to every named resource this module
    creates: the agent, the runbook SOPs, the workflow, the webhook, and BOTH internal
    integrations (`terraform-bot-github`, `terraform-bot-ubuntu`). Use when the same
    Guild tenant must host more than one terraform-bot instance.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.name_suffix == "" || can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$", var.name_suffix))
    error_message = "name_suffix must be empty or kebab-case (lowercase, digits, dashes; no leading/trailing dash)."
  }
}

# ---------------------------------------------------------------------------
# Optional webhook ingress URLs (`POST /api/v1/webhooks/trigger`)
# ---------------------------------------------------------------------------
variable "webhook_trigger_base_url" {
  description = <<-EOT
    Optional StackGen HTTP API origin (e.g. `https://main.dev.stackgen.com`). When set,
    outputs include `webhook_trigger_endpoint` and, when the ingress webhook token exists,
    `webhook_ingress_payload_url` — a full URL with `apiKey=` for GitHub "Payload URL"
    and other senders that cannot set `Authorization: Bearer`. Leave empty (default) to
    omit those computed outputs.
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
