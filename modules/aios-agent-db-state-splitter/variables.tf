variable "stackgen_mcp_integration_name" {
  description = <<-EOT
    **Required.** Guild integration name for the **StackGen MCP** server (same pattern as
    `aios-agent-repo-to-iac`). The StackGen MCP integration is a **tenant-level singleton** —
    this module does **not** provision it (no `aios-integration-stackgen-mcp` exists yet); pass
    the name of a Guild integration backed by the StackGen Consumer MCP (typically
    `stackgen-mcp`). The agent calls AppStack / integrations tools (`create_appstack`,
    `bulk_add_resources_to_appstack`, `bulk_connect_resources_in_appstack`,
    `add_resource_to_appstack`, `connect_resources`, `create_appstack_action_run`,
    `get_appstacks`, env profiles, snapshots, etc.; see **`stackgen-mcp-consumer-tool-catalog-sop`**
    for the user-MCP matrix). This module no longer supports the "TF-only, no AppStack
    materialization" mode: the `materialize-appstacks-coordinator` stage is mandatory and the
    `db-monorepo-state-split-evidence` checklist requires AppStack membership artifacts.
  EOT
  type        = string

  validation {
    condition     = trimspace(var.stackgen_mcp_integration_name) != ""
    error_message = "stackgen_mcp_integration_name is required. Pass the name of a Guild integration backed by the StackGen Consumer MCP (e.g. \"stackgen-mcp\")."
  }
}

variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Policy IDs to attach (expects dangerous_ops from aios-policies)."
  type = object({
    dangerous_ops = string
  })
}

# =============================================================================
# Self-contained integration wiring (replaces the old `integration_names` map).
# Pass `github_secret_id` + `aws_secret_id` and this module provisions its own
# GitHub, Ubuntu, and AWS Guild integrations under module-prefixed names. The
# `existing_*_integration_name` overrides bind to integrations already created
# elsewhere when tenants prefer to share containers across agent modules.
# =============================================================================

variable "github_secret_id" {
  description = <<-EOT
    Optional `sg_secret` ID for the GitHub PAT used by `gh api` and
    `git clone` / `git push` inside the Ubuntu sandbox. When set (and
    `existing_github_integration_name` is empty), this module provisions
    its own GitHub Guild integration internally. When you already manage
    the GitHub integration elsewhere, leave this empty and pass
    `existing_github_integration_name` instead.

    Forward [`aios-integration-github-from-secret`](../aios-integration-github-from-secret).secret_id
    here for the canonical Provider/github shape — the Ubuntu image's
    `pre_launch.sh` surfaces it as `GIT_TOKEN` / `GIT_HOST` / `GIT_USERNAME`.

    One of `github_secret_id` / `existing_github_integration_name` must be
    provided. The same secret can be reused across agent modules (one Vault
    entry per tenant).
  EOT
  type        = string
  default     = ""
}

variable "aws_secret_id" {
  description = <<-EOT
    Optional `sg_secret` (`CloudProvider`/`aws`) ID holding AWS role-assume
    metadata for the read-only role the agent uses to inspect monolith state
    on S3 / DynamoDB / etc. When set (and `existing_aws_integration_name` is
    empty), this module provisions its own AWS Guild integration internally.

    Forward [`aios-integration-aws`](../aios-integration-aws).secret_id here,
    or any pre-existing AWS Guild secret. One of `aws_secret_id` /
    `existing_aws_integration_name` must be provided.
  EOT
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = <<-EOT
    Optional Guild integration name to use for `gh api` calls instead of the
    module-provisioned GitHub integration. When set (non-empty), this module
    does NOT create its own GitHub Guild integration container — it attaches
    the named integration to the agent. Combine with a shared `github_secret_id`
    when many agent modules use the same tenant-level PAT.
  EOT
  type        = string
  default     = ""
}

variable "existing_ubuntu_integration_name" {
  description = <<-EOT
    Optional Guild integration name to use for the Ubuntu CLI sandbox instead
    of the module-provisioned one. When set (non-empty), this module does NOT
    create its own Ubuntu integration. The named integration MUST already have
    the git + AWS secrets attached via `secret_ref_ids` and `tofu`, `gh`,
    `awscli`, `jq`, `git`, `curl` available — see `aios-integration-ubuntu`
    `install_tools`.
  EOT
  type        = string
  default     = ""
}

variable "existing_aws_integration_name" {
  description = <<-EOT
    Optional Guild integration name to use for the AWS MCP sandbox instead of
    the module-provisioned one. When set (non-empty), this module does NOT
    create its own AWS integration. Typical sharing pattern for SREs and IaC
    agents that already have an `aws-production` (or equivalent) integration.
  EOT
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = <<-EOT
    Optional suffix appended to the agent / workflow / runbook / webhook /
    nested integration resource names so multiple instances of this module can
    coexist in one Guild tenant without colliding (e.g. `prod` vs `staging`).
    Empty by default. Forwarded into SOP `templatefile()` calls via
    `module_prefix` so the SOP text references the correct module-prefixed
    tool names at runtime.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

# =============================================================================
# Remote runner attach (optional)
# =============================================================================

variable "remote_runner_name" {
  description = <<-EOT
    Optional Guild remote runner name. When set, SOPs instruct fan-out `tofu plan` / heavy reads on that
    runner when attached. Set `create_remote_runner = true` to register `sg_remote_runner` (provider **>= 0.1.23**)
    and surface CLI/Helm install commands in module outputs for on-prem deployment (outbound-only to mothership).
  EOT
  type        = string
  default     = ""
}

variable "create_remote_runner" {
  description = "When true, creates `sg_remote_runner` via `aios-remote-runner`. Requires non-empty `remote_runner_name`."
  type        = bool
  default     = false

  validation {
    condition     = !var.create_remote_runner || trimspace(var.remote_runner_name) != ""
    error_message = "create_remote_runner requires a non-empty remote_runner_name."
  }
}

variable "remote_runner_description" {
  description = "Runner description when `create_remote_runner` is true."
  type        = string
  default     = ""
}

variable "remote_runner_labels" {
  description = "Optional runner labels when `create_remote_runner` is true."
  type        = map(string)
  default     = {}
}

variable "remote_runner_attach_to_agent" {
  description = <<-EOT
    When true, sets `remote_runners` on the Guild agent (requires non-empty `remote_runner_name`).
    Leave false to only document the runner in SOPs until the runner is online.
  EOT
  type        = bool
  default     = false

  validation {
    condition     = !var.remote_runner_attach_to_agent || trimspace(var.remote_runner_name) != ""
    error_message = "remote_runner_attach_to_agent requires a non-empty remote_runner_name."
  }
}

variable "enable_cce" {
  description = "When true, embeds CCE script pack on the Ubuntu integration for optional application-repo entitlement scans (iac-alignment)."
  type        = bool
  default     = true
}

variable "application_repo_url" {
  description = "Optional GitHub URL of the application repo to CCE-scan alongside Terraform state split (empty skips app CCE)."
  type        = string
  default     = ""
}

variable "enable_github_webhook" {
  description = "When true, creates sg_webhook targeting the primary split workflow (GitHub issue/PR ingress)."
  type        = bool
  default     = false
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional extra skill_refs per primary-workflow stage binding. Keys:
    "db-monorepo-state-split-convergence::<stage_id>" where stage_id is one of:
    ingest-and-split, ingest-blocked-gate, registry-and-import-codegen, shell-converge-matrix,
    materialize-appstacks-coordinator, orphans-secondary-pipeline, final-gate-and-memory.
    Legacy keys (ingest-monolith, discover-db-anchors, hcl-hydrate-per-group,
    materialize-stackgen-appstacks, multi-shard-plan-convergence) are merged via try() fallbacks
    on the new stage ids — map extra skills to the v2 stage ids above.
    Note: `shell-converge-matrix`, `materialize-appstacks-coordinator`, and `orphans-secondary-pipeline`
    are the 3-way parallel layer after `registry-and-import-codegen`; `final-gate-and-memory`
    fans in from all three.
    **Avoid duplicating runbooks:** each stage already has `runbook_refs` + `skill_refs` from this module.
    Adding the same `*-sop` name here forces Guild to prepend `[Skills] load_skill` for content already
    inlined under `[Runbook Context]` — only add **extra** skills that are not the runbook SOPs.
  EOT
  type        = map(list(string))
  default     = {}
}

variable "secondary_workflow_skill_refs" {
  description = <<-EOT
    Optional extra skill_refs per secondary orphan-module workflow stage. Keys:
    "orphan-iac-module-authoring::<stage_id>".
    Prefer not duplicating runbook SOP names already attached via `runbook_refs` on that workflow.
  EOT
  type        = map(list(string))
  default     = {}
}

variable "max_convergence_iterations" {
  description = "Documented cap for count/plan convergence loops (embedded in SOP text for agents)."
  type        = number
  default     = 5

  validation {
    condition     = var.max_convergence_iterations >= 1 && var.max_convergence_iterations <= 20
    error_message = "max_convergence_iterations must be between 1 and 20."
  }
}

variable "default_grouping_strategy" {
  description = <<-EOT
    Default `grouping_strategy` when workflow inputs omit it. Use `tag_seeded_connectivity` for
    connectivity-first splits without an artificial per-AppStack size cap (pair with
    `default_max_resources_per_appstack = 0`). Large monoliths (>5000 resources) auto-promote to
    these defaults when the operator does not override grouping in the webhook payload.
  EOT
  type        = string
  default     = "tag_seeded_connectivity"

  validation {
    condition = contains(
      [
        "policy_first",
        "connectivity",
        "connectivity_capped",
        "tag_seeded_connectivity",
        "tag_seeded_connectivity_capped",
        "type_chunk",
      ],
      var.default_grouping_strategy,
    )
    error_message = "default_grouping_strategy must be a supported allocate_manifest.py strategy."
  }
}

variable "default_max_resources_per_appstack" {
  description = <<-EOT
    Default per-AppStack resource ceiling when workflow inputs omit `max_resources_per_appstack`.
    **0 means unlimited** (no BFS cap-split or seed-bin chunking beyond natural connectivity).
    Positive integers cap shard size (e.g. 120 for smaller plan matrices).
  EOT
  type        = number
  default     = 0

  validation {
    condition     = var.default_max_resources_per_appstack >= 0 && var.default_max_resources_per_appstack <= 100000
    error_message = "default_max_resources_per_appstack must be between 0 (unlimited) and 100000."
  }
}

variable "default_iac_repository_url" {
  description = <<-EOT
    Fallback clone URL when workflow/webhook inputs omit `iac_repository_url`. Empty means the
    architect must receive `iac_repository_url` in the trigger payload (schedule JSON includes it).
  EOT
  type        = string
  default     = ""
}

variable "default_branch" {
  description = "Fallback git branch for IaC push when workflow inputs omit `default_branch`."
  type        = string
  default     = "main"
}

variable "stackgen_project_name" {
  description = <<-EOT
    Default **human-readable** StackGen project name for AppStack MCP calls (`get_appstacks`,
    `create_appstack`, `bulk_add_resources_to_appstack`, …). Must match the project `name` field from
    the StackGen UI or MCP `me` (e.g. `guild-demo`) — **not** the Guild provider `project_id` UUID.
    Mirrored to workflow notes at `ingest-and-split` when the workflow input omits `stackgen_project_name`.
    When empty, the materialize stage calls MCP `me` and picks a project from `projects[]`.
  EOT
  type        = string
  default     = ""

  validation {
    condition = (
      trimspace(var.stackgen_project_name) == ""
      || !can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", trimspace(var.stackgen_project_name)))
    )
    error_message = "stackgen_project_name must be the human-readable StackGen project name (e.g. guild-demo), not a UUID. Guild provider project_id is a separate identifier."
  }
}

variable "subagent_budgets" {
  description = <<-EOT
    Optional overrides for create_agent subagent budgets (Guild clamps max_llm_calls to [8, 60]
    and max_tool_iterations to [40, 50]). Raise script_runner_max_llm_calls when ingest-and-split
    hits "max LLM calls exceeded" during download/split-manifest; raise registry_codegen_max_llm_calls
    for large-state scaffold + show -json chunking.
  EOT
  type = object({
    script_runner_max_llm_calls                = optional(number)
    script_runner_max_tool_iterations          = optional(number)
    script_runner_timeout_seconds              = optional(number)
    registry_codegen_max_llm_calls             = optional(number)
    registry_codegen_max_tool_iterations       = optional(number)
    registry_codegen_timeout_seconds           = optional(number)
    hcl_hydrate_batch_max_llm_calls            = optional(number)
    hcl_hydrate_batch_max_tool_iterations      = optional(number)
    hcl_hydrate_batch_timeout_seconds          = optional(number)
    appstack_batch_max_llm_calls               = optional(number)
    appstack_batch_max_tool_iterations         = optional(number)
    appstack_batch_timeout_seconds             = optional(number)
    plan_convergence_batch_max_llm_calls       = optional(number)
    plan_convergence_batch_max_tool_iterations = optional(number)
    plan_convergence_batch_timeout_seconds     = optional(number)
    mcp_shell_runner_max_llm_calls             = optional(number)
    mcp_shell_runner_max_tool_iterations       = optional(number)
    mcp_shell_runner_timeout_seconds           = optional(number)
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Optional webhook ingress URLs (`POST /api/v1/webhooks/trigger`)
# ---------------------------------------------------------------------------
variable "webhook_trigger_base_url" {
  description = <<-EOT
    Optional StackGen HTTP API origin (e.g. `https://main.dev.stackgen.com`). When set,
    outputs include `webhook_trigger_endpoint` and, when the GitHub ingress webhook token
    exists, `webhook_ingress_payload_url` — a full URL with `apiKey=` for GitHub "Payload URL"
    and other senders that cannot set `Authorization: Bearer`. Leave empty (default) to omit.
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
