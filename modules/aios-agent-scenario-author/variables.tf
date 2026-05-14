variable "model_names" {
  description = "Ordered list of registered model names exposed to the scenario-author agent (highest preference first). Forwarded to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Map of policy IDs to attach to the scenario-author agent. dangerous_ops is required so destructive shell behaviour stays gated by the org guardrail."
  type = object({
    dangerous_ops = string
  })
}

variable "github_secret_id" {
  description = <<-EOT
    ID of a pre-existing `sg_secret` holding the GitHub PAT this bot uses to fetch issues,
    clone the repo, open the scaffold PR, and comment back on the originating issue. The
    same secret is bound to BOTH integrations this module provisions internally:
      - the `scenario-author-github` Guild integration (for `gh api` calls from the API
        sandbox), and
      - the `scenario-author-ubuntu` Guild integration (so `gh auth status` /
        `git clone` / `gh pr create` work inside the shell sandbox without the agent
        having to thread a token through subagent goals).

    Required. Recommended PAT scopes: `repo`, `read:org`. Pass `sg_secret.<name>.id` from
    the consumer root. Use the same secret across multiple agent modules to keep ONE PAT
    in Vault per tenant.
  EOT
  type        = string

  validation {
    condition     = trimspace(var.github_secret_id) != ""
    error_message = "github_secret_id is required; the scenario-author bot cannot fetch issues or open PRs without it."
  }
}

variable "existing_github_integration_name" {
  description = <<-EOT
    Optional. When set, this module SKIPS provisioning its own `scenario-author-github`
    Guild integration and attaches the agent to the supplied existing integration name
    instead. Use this when the tenant already runs a shared `github-integration`
    container that you want the agent to share, rather than spinning up a per-bot
    container. Default `""` keeps the self-contained behaviour.
  EOT
  type        = string
  default     = ""
}

variable "existing_ubuntu_integration_name" {
  description = <<-EOT
    Optional. When set, this module SKIPS provisioning its own `scenario-author-ubuntu`
    Guild integration and attaches the agent to the supplied existing integration name
    instead. Note the existing Ubuntu container must already have the GitHub PAT
    surfaced as `GH_TOKEN` env (otherwise `gh` / `git clone` will fail inside the
    sandbox). Default `""` keeps the self-contained behaviour.
  EOT
  type        = string
  default     = ""
}

variable "repository_full_name" {
  description = <<-EOT
    The GitHub repository (`owner/name`) this bot is allowed to operate on.
    The orchestration SOP enforces a hard gate (§0c): if a webhook event
    arrives for any other repo, the bot posts a "wrong repo" comment and
    stops. Default targets the public scenario library repo.
  EOT
  type        = string
  default     = "appcd-dev/solutions"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repository_full_name))
    error_message = "repository_full_name must be in the form `owner/name`."
  }
}

variable "scenario_request_label" {
  description = <<-EOT
    The GitHub issue label that gates this bot. Only issues carrying this
    label are scaffolded into PRs; anything else gets a polite "missing
    label" reply. Default matches the label set by
    `.github/ISSUE_TEMPLATE/scenario-request.md`.
  EOT
  type        = string
  default     = "scenario-request"

  validation {
    condition     = trimspace(var.scenario_request_label) != ""
    error_message = "scenario_request_label must not be empty."
  }
}

variable "agent_budget" {
  description = <<-EOT
    Daily USD spend cap for the scenario-author agent. The full happy-path
    workflow (analyze-issue + triage + scaffold + PR + notify) typically
    costs $2-$4 per run; $10/day fits comfortably with retries.
  EOT
  type        = number
  default     = 10

  validation {
    condition     = var.agent_budget > 0
    error_message = "agent_budget must be positive."
  }
}

variable "enable_webhook" {
  description = <<-EOT
    When true (default), provisions the `sg_webhook` ingress so GitHub
    `issue.created` events trigger the workflow automatically. Set false
    for dry-run / staging tenants where you want to register the workflow
    but invoke it manually through Guild's "Run workflow" UI.
  EOT
  type        = bool
  default     = true
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs appended to each stage_binding. Keys are
    "scenario-request-triage::<stage_id>" where stage_id matches one of:
    `analyze-issue`, `triage`, `scaffold-validate-pr`, `notify-issue-comment`.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}

variable "name_suffix" {
  description = <<-EOT
    Optional suffix appended (with a leading `-`) to every named resource this
    module creates: the agent, the four runbook SOPs, the workflow, the
    webhook, and BOTH internal integrations (`scenario-author-github`,
    `scenario-author-ubuntu`). Use when the same Guild tenant must host more
    than one scenario-author instance — e.g. one bot per repo. Default `""`
    keeps the canonical names.

    Allowed characters: lowercase letters, digits, `-`. Leading / trailing `-`
    are stripped.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.name_suffix == "" || can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$", var.name_suffix))
    error_message = "name_suffix must be empty or kebab-case (lowercase, digits, dashes; no leading/trailing dash)."
  }
}

variable "trigger_event_types" {
  description = <<-EOT
    StackGen normalized event types that fire the workflow. Default is a
    superset that covers known Guild webhook dialects:
      - `issue.created` (the value `aios-agent-terraform-bot` uses)
      - `issues.opened` (GitHub's native action name; some Guild versions pass-through)
      - `issues.labeled` (so SEs who file then label still get triaged)

    Override when your Guild release is known to normalize differently. The
    agent's repo + label gate (orchestration SOP §0c) filters anything that
    sneaks through, so over-triggering is safe.
  EOT
  type        = list(string)
  default     = ["issue.created", "issues.opened", "issues.labeled"]

  validation {
    condition     = length(var.trigger_event_types) > 0
    error_message = "trigger_event_types must contain at least one event type string."
  }
}
