variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
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

variable "github_token" {
  description = <<-EOT
    GitHub PAT for clone, `gh api`, issue comments, and PR creation on the remote runner.
    When set, this module creates a flat env `sg_secret` (`GIT_TOKEN`, `GH_TOKEN`, …) and
    binds it to the remote runner via `typed_secret_refs.github`. Mutually exclusive with
    `github_secret_id`. Recommended scopes: `repo`, `read:org`.
  EOT
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_secret_id" {
  description = <<-EOT
    ID of a pre-existing `sg_secret` holding the GitHub PAT. Use when the PAT already lives
    in Vault with flat runner env keys (`GIT_TOKEN`, `GH_TOKEN`, `GITHUB_TOKEN`, …). Bound
    to the remote runner via `typed_secret_refs.github`. Mutually exclusive with
    `github_token`. Exactly one of `github_token` / `github_secret_id` is required.
  EOT
  type        = string
  default     = ""
}

variable "runner_work_home" {
  description = "Home directory on the remote runner host (default `/home/runner`). Pack path is `<runner_work_home>/.cdk-bot/pack/<version>/`."
  type        = string
  default     = "/home/runner"
}

variable "build_runner_image" {
  description = "When true (default), run `docker build` during apply to bake the workflow script pack into the CDK runner image."
  type        = bool
  default     = true
}

variable "runner_docker_image_repository" {
  description = "Local Docker image repository name for the CDK runner (default `cdk-bot-runner`)."
  type        = string
  default     = "cdk-bot-runner"
}

variable "runner_docker_image_tag" {
  description = "Docker image tag for the CDK runner. Defaults to `script_pack_version` when empty."
  type        = string
  default     = ""
}

variable "aiden_runner_base_image" {
  description = "Base aiden-runner image passed as Docker build-arg `AIDEN_RUNNER_IMAGE`."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-aiden-runner:main"
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "cdk-app-update::<stage_id>" where stage_id is `clone`, `implement-cdk`, or `validate`.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}

variable "remote_runner_name" {
  description = <<-EOT
    Guild remote runner name. Defaults to `cdk-bot-runner[-<suffix>]` when empty.
    When `create_remote_runner` is true, registers `sg_remote_runner` (provider **>= 0.1.25**) and exposes CLI/Helm
    install commands in module outputs. GitHub PAT is bound via `typed_secret_refs.github` for git/gh on the runner.
  EOT
  type        = string
  default     = ""
}

variable "create_remote_runner" {
  description = <<-EOT
    When true (default), creates `sg_remote_runner` via nested `aios-remote-runner`.
    Apply Terraform, build the CDK runner image (`build_runner_image`), then run `remote_runner_cli_start_command_with_secrets`
    from outputs (or `docker run` with `runner_docker_image`) before triggering workflows.
  EOT
  type        = bool
  default     = true
}

variable "remote_runner_description" {
  description = "Description for the runner when `create_remote_runner` is true. Defaults to a module-specific sentence."
  type        = string
  default     = ""
}

variable "remote_runner_labels" {
  description = "Optional labels when `create_remote_runner` is true (e.g. env, region)."
  type        = map(string)
  default     = {}
}

variable "remote_runner_attach_to_agent" {
  description = <<-EOT
    When true (default), attaches the CDK runner to the agent via `sg_agent.remote_runners`.
  EOT
  type        = bool
  default     = true
}

variable "runner_script_pack_env_secret_id" {
  description = <<-EOT
    Pre-existing vault secret UUID whose generic metadata `value` JSON includes `CDKBOT_SCRIPT_PACK_*`
    keys. When empty and `create_remote_runner` is true, the module provisions
    `cdk-bot-runner-script-pack-env` and binds it via generic runner sync.
  EOT
  type        = string
  default     = ""
}

variable "remote_runner_secret_sync_enabled" {
  description = "When true (default), binds script-pack generic secret (and any `remote_runner_generic_secret_ref_ids`) on the remote runner."
  type        = bool
  default     = true
}

variable "remote_runner_generic_secret_ref_ids" {
  description = "Extra generic vault secret UUIDs merged into remote runner mothership sync."
  type        = list(string)
  default     = []
}

variable "remote_runner_secrets_sync_interval_seconds" {
  description = "Poll interval for aiden-runner `--secrets-sync-interval` when secrets are bound (15–3600, default 60)."
  type        = number
  default     = 60
}

variable "name_suffix" {
  description = <<-EOT
    Optional suffix appended (with a leading `-`) to every named resource this module
    creates: the agent, the runbook SOPs, the workflow, the webhook, and optional AWS integration.
    Use when the same Guild tenant must host more than one cdk-bot instance.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.name_suffix == "" || can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$", var.name_suffix))
    error_message = "name_suffix must be empty or kebab-case (lowercase, digits, dashes; no leading/trailing dash)."
  }
}

# ---------------------------------------------------------------------------
# Optional webhook ingress URLs (`POST /guild/api/v1/webhooks/trigger` on StackGen public origins)
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
    `repository.full_name` matches an entry, the bot loads the discovery-modules layout SOP
    and may scaffold via `implement-cdk-catalog-scaffold`. Set to `[]` to disable (default).
  EOT
  type        = list(string)
  default     = []
}

variable "discovery_modules_issue_label" {
  description = <<-EOT
    GitHub label gate for discovery-modules repos (same pattern as
    `aios-agent-scenario-author` / `scenario-request`). The intake stage requires this
    label on the triggering issue before cloning. Leave empty to accept any issue on
    configured discovery repos. Default: `cdk-construct-request`.
  EOT
  type        = string
  default     = "cdk-construct-request"
}

variable "require_draft_pr" {
  description = "When true (default), `gh pr create --draft` for human merge gate."
  type        = bool
  default     = true
}

variable "enable_aws_validation" {
  description = <<-EOT
    When true, provisions optional AWS integration for lookup-heavy synth and cdk diff.
    Operator must complete Guild/Vault AWS wizard (bastion trust + customer role ARN) before apply.
    Default false — hermetic validate (no AWS creds).
  EOT
  type        = bool
  default     = false
}

variable "existing_aws_integration_name" {
  description = "Preferred path: attach existing tenant AWS integration from Guild wizard."
  type        = string
  default     = ""
}

variable "aws_role_arn" {
  description = "Customer account IAM role ARN (trusts Vault bastion). Used when creating a new AWS integration."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for optional validation integration."
  type        = string
  default     = "us-east-1"
}

variable "auto_approve_integration_tools" {
  description = <<-EOT
    When true (default), sets sg_agent.auto_approve_tools for the remote runner tool
    wildcard so clone/validate/gh execute_series are not blocked by HITL in dev.
  EOT
  type        = bool
  default     = true
}

variable "enable_progress_issue_comment" {
  description = <<-EOT
    When true (default), each agent stage spawns progress-comment-updater (Template P) to POST then PATCH
    a single GitHub issue comment with live workflow status. create-pr-notify/comment skip duplicate POSTs
    when progress_comment_id is already in notes.
  EOT
  type        = bool
  default     = true
}

variable "draft_pr_on_max_iterations_exhausted" {
  description = <<-EOT
    When true (default), after `validate-loop-gate` exhausts iterations the validate stage
    posts a blocked summary with `test_summary_tail` while leaving the draft PR open for human review.
    When false, max-iter exhaustion is notify-only.
  EOT
  type        = bool
  default     = true
}

variable "module_quality_max_iterations" {
  description = <<-EOT
    Maximum number of times `validate-loop-gate` may return to **implement-cdk**
    when quality is still not PASS. Keep low (default 1): Guild aborts when any stage
    exceeds 5 visits — edit + validate-loop both consume the visit budget.
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.module_quality_max_iterations >= 1 && var.module_quality_max_iterations <= 10
    error_message = "module_quality_max_iterations must be between 1 and 10."
  }
}

variable "subagent_budgets" {
  description = <<-EOT
    Optional overrides for subagent spawn budgets (host clamps max_llm_calls to [8, 60]
    and max_tool_iterations to [40, 50]). Raise implement_max_llm_calls when implement-cdk-app-update
    hits "max LLM calls exceeded"; shell runners rarely need more than 25.
  EOT
  type = object({
    runner_max_llm_calls      = optional(number)
    runner_timeout_seconds    = optional(number)
    validate_max_llm_calls    = optional(number)
    validate_timeout_seconds  = optional(number)
    implement_max_llm_calls   = optional(number)
    implement_timeout_seconds = optional(number)
    github_max_llm_calls      = optional(number)
    github_timeout_seconds    = optional(number)
  })
  default = {}

  # Note: optional() keys in an object-typed variable default to null when unset.
  # main.tf coalesces each key against subagent_budget_defaults — do not merge() directly.
}
