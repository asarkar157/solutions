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
    name instead.     Note: the existing Ubuntu integration must already have the GitHub PAT wired via
    `secret_ref_ids` as a `Provider/github` secret (surfaced as `GIT_TOKEN` / `GH_TOKEN`
    in the container env). Otherwise `gh` / `git clone` will fail inside the sandbox.
    Default `""` keeps the self-contained behaviour.
  EOT
  type        = string
  default     = ""
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "terraform-module-update::<stage_id>" where stage_id matches the workflow stage (e.g. check-info-and-clone, implement-module, validate-and-test, create-pr).
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

variable "discovery_modules_repository_full_names" {
  description = <<-EOT
    GitHub repositories that follow the StackGen discovery-modules layout (`aws/`, `gcp/`,
    `azurerm/<module>/` with `.stackgen/stackgen.yaml`). When the webhook payload's
    `repository.full_name` matches an entry, the bot loads the discovery-modules layout SOP:
    checks module existence under provider roots, scaffolds resource templates (Template I),
    validates `stackgen.yaml`, and uses `stackgen upload custom-modules` on registration.
    Default includes `stackgenhq/discovery-modules`. Set to `[]` to disable the profile.
  EOT
  type        = list(string)
  default     = ["stackgenhq/discovery-modules"]
}

variable "discovery_modules_issue_label" {
  description = <<-EOT
    GitHub label gate for discovery-modules repos (same pattern as
    `aios-agent-scenario-author` / `scenario-request`). The intake stage requires this
    label on the triggering issue before cloning. Leave empty to accept any issue on
    configured discovery repos. Default: `discovery-module-request`. Legacy alias
    `analyze-request` is accepted during migration (see discovery layout SOP §1).
  EOT
  type        = string
  default     = "discovery-module-request"
}

variable "stackgen_upload_url" {
  description = <<-EOT
    Optional StackGen base URL passed to `stackgen upload custom-modules` when registering
    discovery modules (e.g. `https://main.dev.stackgen.com`). Leave empty to use the CLI default.
  EOT
  type        = string
  default     = ""
}

variable "stackgen_upload_project_id" {
  description = <<-EOT
    Optional StackGen project id for `stackgen upload custom-modules --project` when registering
    discovery modules after a successful PR scaffold.
  EOT
  type        = string
  default     = ""
}

variable "stackgen_token_secret_id" {
  description = <<-EOT
    Optional `sg_secret` id whose metadata exposes `STACKGEN_TOKEN` in the Ubuntu sandbox
    (same pattern as AWS/git secrets on `secret_ref_ids`). Required for `stackgen register`
    and `stackgen upload custom-modules` on discovery-modules repos. When empty, registration
    stages note `registration_skipped=missing_stackgen_token` and post a blocked summary for
    discovery uploads.
  EOT
  type        = string
  default     = ""
}

variable "defer_pr_until_quality_pass" {
  description = <<-EOT
    When true (default), `create-pr` defers `gh pr create` until `module_quality_summary`
    is PASS with all `quality_check_*` sentinels PASS. Avoids reviewers seeing failing WIP PRs.
  EOT
  type        = bool
  default     = true
}

variable "module_quality_max_iterations" {
  description = <<-EOT
    Maximum number of times `validate-loop-gate` may return to `implement-module`
    when quality is still not PASS. When the budget is exhausted, `create-pr` still runs
    but posts a blocked summary (no StackGen upload) even if the agent still emitted NEEDS_REVISION.
  EOT
  type        = number
  default     = 3

  validation {
    condition     = var.module_quality_max_iterations >= 1 && var.module_quality_max_iterations <= 10
    error_message = "module_quality_max_iterations must be between 1 and 10."
  }
}

variable "subagent_budgets" {
  description = <<-EOT
    Optional overrides for create_agent subagent budgets (Guild clamps max_llm_calls to [8, 60]
    and max_tool_iterations to [40, 50]). Raise hcl_author_max_llm_calls when discovery/registry
    scaffolds hit "max LLM calls exceeded"; script runners rarely need more than 25.
  EOT
  type = object({
    script_runner_max_llm_calls     = optional(number)
    github_fetch_max_llm_calls      = optional(number)
    github_comment_max_llm_calls    = optional(number)
    validate_runner_max_llm_calls   = optional(number)
    hcl_author_max_llm_calls        = optional(number)
    script_runner_timeout_seconds   = optional(number)
    github_fetch_timeout_seconds    = optional(number)
    github_comment_timeout_seconds  = optional(number)
    validate_runner_timeout_seconds = optional(number)
    hcl_author_timeout_seconds      = optional(number)
  })
  default = {}

  # Note: optional() keys in an object-typed variable default to null when unset.
  # main.tf coalesces each key against subagent_budget_defaults — do not merge() directly.
}
