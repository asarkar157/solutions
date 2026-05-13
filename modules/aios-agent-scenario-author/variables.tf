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

variable "integration_names" {
  description = <<-EOT
    Guild integration names attached to the scenario-author agent.

    - `github` (required) — GitHub Guild integration. The agent uses it to call
      `gh api`, `gh auth token`, and to fetch the triggering issue. Must be
      authenticated against the repository named in `repository_full_name`.
    - `ubuntu_cli` (required) — Ubuntu CLI Guild integration. The agent uses
      it to `git clone` the repo, scaffold files, run `tofu fmt`/`validate`,
      `gh pr create`, and `gh issue comment`. Provision via
      `modules/aios-integration-ubuntu` and pass `integration_name` as
      `ubuntu_cli`. The runbooks install the `gh` CLI on first use.

    Both are required (see validation). Omitting `ubuntu_cli` leaves only
    GitHub API access and breaks the scaffold / validate / PR flow.
  EOT
  type = object({
    github     = string
    ubuntu_cli = string
  })

  validation {
    condition     = trimspace(var.integration_names.github) != "" && trimspace(var.integration_names.ubuntu_cli) != ""
    error_message = "integration_names.github and integration_names.ubuntu_cli must both be non-empty."
  }
}

variable "repository_full_name" {
  description = <<-EOT
    The GitHub repository (`owner/name`) this bot is allowed to operate on.
    The orchestration SOP enforces a hard gate (§0c): if a webhook event
    arrives for any other repo, the bot posts a "wrong repo" comment and
    stops. Default targets the public scenario library repo.
  EOT
  type        = string
  default     = "appcd-dev/aios-modules"

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
    module creates: the agent, the four runbook SOPs, the workflow, and the
    webhook. Use when the same Guild tenant must host more than one
    scenario-author instance — e.g. one bot per repo. Default `""` keeps the
    canonical names (`scenario-author`, `scenario-request-triage`, etc.).

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
