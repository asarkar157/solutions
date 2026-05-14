variable "stackgen_mcp_integration_name" {
  description = <<-EOT
    **Required.** Guild integration name for the **StackGen MCP** server (same pattern as
    `aios-agent-repo-to-iac`). The StackGen MCP integration is a **tenant-level singleton** —
    this module does **not** provision it (no `aios-integration-stackgen-mcp` exists yet); pass
    the name of a Guild integration backed by the StackGen Consumer MCP (typically
    `stackgen-mcp`). The agent calls AppStack / integrations tools (`create_appstack`,
    `add_resource_to_appstack`, `connect_resources`, `create_appstack_action_run`,
    `get_appstacks`, env profiles, snapshots, etc.; see **`stackgen-mcp-consumer-tool-catalog-sop`**
    for the user-MCP matrix). This module no longer supports the "TF-only, no AppStack
    materialization" mode: the `materialize-stackgen-appstacks` stage is mandatory and the
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
    Optional Guild remote runner name (operator-provisioned). When set, SOPs instruct fan-out
    `tofu plan` / heavy reads to run on that runner when the agent has a remote-runner tool;
    otherwise plans run in the Ubuntu CLI sandbox. This module does not create runners — the
    StackGen provider exposes `sg_remote_runner` / `sg_remote_runners` as read-only data sources.
  EOT
  type        = string
  default     = ""
}

variable "remote_runner_attach_to_agent" {
  description = <<-EOT
    When true, looks up `remote_runner_name` with `data.sg_remote_runner` and sets `remote_runners`
    on the Guild agent so tool dispatch may use that runner (provider **>= 0.1.13**). Requires a
    non-empty `remote_runner_name` and provider `project_id` / `org_id` when the API is org-scoped.
    Leave false to only document the runner in SOPs without Terraform-level attachment.
  EOT
  type        = bool
  default     = false

  validation {
    condition     = !var.remote_runner_attach_to_agent || trimspace(var.remote_runner_name) != ""
    error_message = "remote_runner_attach_to_agent requires a non-empty remote_runner_name."
  }
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
    ingest-monolith, discover-db-anchors, allocate-related-resources, count-reconcile-loop,
    registry-and-import-codegen, hcl-hydrate-per-group, materialize-stackgen-appstacks,
    orphans-secondary-pipeline, multi-shard-plan-convergence, final-gate-and-memory.
    Note: `hcl-hydrate-per-group`, `materialize-stackgen-appstacks`, and `orphans-secondary-pipeline`
    are the 3-way parallel layer after `registry-and-import-codegen`; `multi-shard-plan-convergence`
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
