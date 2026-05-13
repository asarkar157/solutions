variable "stackgen_mcp_integration_name" {
  description = <<-EOT
    **Required.** Guild integration name for the **StackGen MCP** server (same pattern as `aios-agent-repo-to-iac`).
    The agent calls AppStack / integrations tools (`create_appstack`, `add_resource_to_appstack`,
    `connect_resources`, `create_appstack_action_run`, `get_appstacks`, env profiles, snapshots, etc. — see
    **`stackgen-mcp-consumer-tool-catalog-sop`** for the user-MCP matrix). This module no longer supports the
    "TF-only, no AppStack materialization" mode: the `materialize-stackgen-appstacks` stage is mandatory and the
    `db-monorepo-state-split-evidence` checklist requires AppStack membership artifacts. Provision the StackGen
    Consumer MCP integration (see `examples/agentic-infrastructure`) and pass its name here.
  EOT
  type        = string

  validation {
    condition     = trimspace(var.stackgen_mcp_integration_name) != ""
    error_message = "stackgen_mcp_integration_name is required. Pass the name of a Guild integration backed by the StackGen Consumer MCP (e.g. \"stackgen-mcp\")."
  }
}

variable "model_names" {
  description = "Map of model keys to actual deployed model names (from aios-foundation)."
  type = object({
    gpt4o         = string
    claude_sonnet = string
    gemini_flash  = string
  })
}

variable "policy_ids" {
  description = "Policy IDs to attach (expects dangerous_ops from aios-policies)."
  type = object({
    dangerous_ops = string
  })
}

variable "integration_names" {
  description = <<-EOT
    Guild integrations. **All three keys are required:**
    - **`github`** — metadata / filtered `gh api`. Provision via `modules/aios-integration-github`.
    - **`ubuntu_cli`** — shell surface for state pull, `jq`, OpenTofu/Terraform, multi-root plans, `gh`
      with a real clone. Provision via `modules/aios-integration-ubuntu`.
    - **`aws`** — AWS Guild integration (`type = "aws"`) so the agent can call `aws_cli_*` MCP tools
      for state inspection. Provision via `modules/aios-integration-aws` (or any equivalent
      `sg_guild_integration` of `type = "aws"`).

    Pair this with the required `stackgen_mcp_integration_name` for AppStack MCP tools.

    **State backends + `tofu plan` connectivity (operator-owned wiring):** the AWS Guild integration
    above exposes `aws_cli_*` tools, but `tofu plan -generate-config-out` and `tofu plan` need AWS
    credentials inside the **Ubuntu** container (env-var auth chain). Attach a read-only AWS secret to
    the Ubuntu integration via `sg_guild_integration.secret_ref_ids` (e.g. `AWS_ACCESS_KEY_ID` /
    `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` metadata, or an STS-rotated equivalent). This module does
    not perform that wiring — see the module README "Operator prerequisites" section.
  EOT
  type = object({
    github     = string
    ubuntu_cli = string
    aws        = string
  })

  validation {
    condition = (
      trimspace(var.integration_names.github) != ""
      && trimspace(var.integration_names.ubuntu_cli) != ""
      && trimspace(var.integration_names.aws) != ""
    )
    error_message = "integration_names.github, integration_names.ubuntu_cli, and integration_names.aws must all be non-empty."
  }
}

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
