variable "stackgen_mcp_integration_name" {
  description = <<-EOT
    Optional Guild integration name for the **StackGen MCP** server (same pattern as `aios-agent-repo-to-iac`).
    When non-empty, the agent can call AppStack / discovery tools (`create_appstack`, `add_resource_to_appstack`,
    `create_appstack_from_discovered_resources`, `download-iac`, etc.). When empty, SOPs instruct skipping
    StackGen materialization while still performing TF-only grouping and plans.
  EOT
  type        = string
  default     = ""
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
    Guild integrations: **GitHub** (metadata / filtered `gh api`); **Ubuntu CLI** (state pull, jq,
    OpenTofu/Terraform, multi-root plans, `gh` with a real clone). Pair with optional
    `stackgen_mcp_integration_name` for AppStack MCP tools.
    Provision `modules/aios-integration-ubuntu` and pass its `integration_name` as `ubuntu_cli`.
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
    reverse-engineer-and-registry-map, materialize-stackgen-appstacks, orphans-secondary-pipeline,
    multi-shard-plan-convergence, final-gate-and-memory.
  EOT
  type        = map(list(string))
  default     = {}
}

variable "secondary_workflow_skill_refs" {
  description = <<-EOT
    Optional extra skill_refs per secondary orphan-module workflow stage. Keys:
    "orphan-iac-module-authoring::<stage_id>".
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
