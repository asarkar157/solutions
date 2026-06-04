variable "model_names" {
  description = "Ordered list of registered model names for module agents (highest preference first)."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Policy IDs to attach (expects dangerous_ops; optional container_shell_hitl when Cursor extract is enabled)."
  type = object({
    dangerous_ops        = string
    container_shell_hitl = optional(string)
  })
}

variable "github_secret_id" {
  description = "Optional sg_secret ID for GitHub PAT. Provisions GitHub integration when set and existing_github_integration_name is empty."
  type        = string
  default     = ""
}

variable "existing_github_integration_name" {
  description = "Optional existing GitHub Guild integration name (skips provisioning)."
  type        = string
  default     = ""
}

variable "existing_ubuntu_integration_name" {
  description = "Optional existing Ubuntu CLI integration (must have git token on secret_ref_ids)."
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Optional suffix for agent/workflow/SOP names (e.g. prod, staging)."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}

variable "enable_cursor_integration" {
  description = "Register cursor-split-executor agent and enable cursor-refactor-services stage in extract workflow."
  type        = bool
  default     = false
}

variable "existing_cursor_mcp_integration_name" {
  description = "Guild integration name for Cursor MCP (required when enable_cursor_integration = true)."
  type        = string
  default     = ""
}

variable "enable_github_webhook" {
  description = "When true, creates sg_webhook targeting the analysis workflow."
  type        = bool
  default     = false
}

variable "default_branch" {
  description = "Fallback git default branch for PR base (never push here)."
  type        = string
  default     = "main"
}

variable "default_split_strategy" {
  description = "Default split_strategy when workflow inputs omit it (ddd | layer | team_topology)."
  type        = string
  default     = "ddd"

  validation {
    condition     = contains(["ddd", "layer", "team_topology"], var.default_split_strategy)
    error_message = "default_split_strategy must be ddd, layer, or team_topology."
  }
}

variable "max_recommended_services" {
  description = "Cap on proposed microservices in analyst synthesis (embedded in SOP text)."
  type        = number
  default     = 12

  validation {
    condition     = var.max_recommended_services >= 2 && var.max_recommended_services <= 50
    error_message = "max_recommended_services must be between 2 and 50."
  }
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional extra skill_refs per workflow stage. Keys:
    "monorepo-services-split-analysis::<stage_id>" or
    "monorepo-services-split-extract::<stage_id>".
  EOT
  type        = map(list(string))
  default     = {}
}

variable "integration_names" {
  description = <<-EOT
    Optional map of pre-provisioned Guild integration names (same pattern as db-state-splitter).
    Keys: `github`, `ubuntu_cli`. When set, skips provisioning for that integration.
  EOT
  type        = map(string)
  default     = {}
}

variable "subagent_budgets" {
  description = "Optional overrides for spawn_contract subagent budgets."
  type = object({
    boundary_scan_max_llm_calls            = optional(number)
    boundary_scan_max_tool_iterations      = optional(number)
    boundary_scan_timeout_seconds          = optional(number)
    guidance_pr_max_llm_calls              = optional(number)
    guidance_pr_max_tool_iterations        = optional(number)
    guidance_pr_timeout_seconds            = optional(number)
    scaffold_services_max_llm_calls        = optional(number)
    scaffold_services_max_tool_iterations  = optional(number)
    scaffold_services_timeout_seconds      = optional(number)
    extract_pr_max_llm_calls               = optional(number)
    extract_pr_max_tool_iterations         = optional(number)
    extract_pr_timeout_seconds             = optional(number)
    targeted_cce_max_llm_calls             = optional(number)
    targeted_cce_max_tool_iterations       = optional(number)
    targeted_cce_timeout_seconds           = optional(number)
    synthesize_plan_max_llm_calls          = optional(number)
    synthesize_plan_max_tool_iterations    = optional(number)
    synthesize_plan_timeout_seconds        = optional(number)
    agents_md_scaffold_max_llm_calls       = optional(number)
    agents_md_scaffold_max_tool_iterations = optional(number)
    agents_md_scaffold_timeout_seconds     = optional(number)
    fetch_repo_context_max_llm_calls       = optional(number)
    fetch_repo_context_max_tool_iterations = optional(number)
    fetch_repo_context_timeout_seconds     = optional(number)
  })
  default = {}
}

variable "policy_create_flags" {
  description = "When container_shell_hitl is true, attach to cursor-split-executor."
  type = object({
    container_shell_hitl = optional(bool, true)
  })
  default = {}
}

variable "webhook_trigger_base_url" {
  description = "Optional StackGen API origin for webhook_trigger_endpoint output."
  type        = string
  default     = ""
}

variable "webhook_trigger_org_id" {
  description = "Optional orgId query param for webhook_ingress_payload_url."
  type        = string
  default     = ""
}

variable "script_pack_git_ref" {
  description = "Deprecated — script pack is embedded in the Ubuntu sidecar at tofu apply (MONOSPLIT_SCRIPT_PACK_TARBALL_B64). Ignored."
  type        = string
  default     = ""
}

variable "script_pack_git_repo" {
  description = "Deprecated — script pack is embedded in the Ubuntu sidecar at tofu apply. Ignored; workflows do not clone tooling repos at runtime."
  type        = string
  default     = ""
}

variable "enable_cce_enhanced" {
  description = "When true, wires aios-cce-scripts pack and runs cce plan + cce run -recipes on critical-path dirs during boundary scan."
  type        = bool
  default     = true
}

variable "cce_recipes" {
  description = "Comma-separated CCE recipe ids for monorepo scan (parse-once via cce run -recipes). Must be catalog recipe ids from releases.stackgen.com/cce/recipes."
  type        = string
  default     = "cloud-entitlements,microservice-decomposition,platform-adoption"
}

variable "cce_lens_use_cases" {
  description = "Comma-separated lens slugs from releases.stackgen.com/cce/lenses (cce-scan.sh scan-use-case). Empty disables Tier-1 lens add-on passes."
  type        = string
  default     = "monorepo-intelligence,integration-replatforming"
}

variable "cce_critical_path_max_dirs" {
  description = "Max directory scopes for path-limited CCE scans on large monorepos."
  type        = number
  default     = 8

  validation {
    condition     = var.cce_critical_path_max_dirs >= 1 && var.cce_critical_path_max_dirs <= 30
    error_message = "cce_critical_path_max_dirs must be between 1 and 30."
  }
}

variable "cce_full_tree_max_files" {
  description = "When cce plan candidate_file_count is at or below this threshold, run full-tree CCE instead of critical-path only."
  type        = number
  default     = 800
}

variable "non_trivial_model_names" {
  description = "Optional override for architect/analyst model_names excluding mini/flash/efficiency models. Empty uses filtered model_names."
  type        = list(string)
  default     = []
}

variable "subagent_task_type" {
  description = "task_type for terminal_calling spawn contracts (default terminal_calling for paste-only runners)."
  type        = string
  default     = "terminal_calling"
}

variable "create_remote_runner" {
  description = "When true, registers sg_remote_runner via aios-remote-runner for large monorepo CCE scans."
  type        = bool
  default     = false
}

variable "remote_runner_name" {
  description = "Remote runner name. Defaults to monorepo-services-splitter-runner when create_remote_runner is true."
  type        = string
  default     = ""
}

variable "remote_runner_description" {
  description = "Description for sg_remote_runner when create_remote_runner is true."
  type        = string
  default     = ""
}

variable "remote_runner_labels" {
  description = "Optional labels for sg_remote_runner when create_remote_runner is true."
  type        = map(string)
  default     = {}
}

variable "remote_runner_attach_to_agent" {
  description = "When true, attaches remote runner to monorepo-split-architect agent."
  type        = bool
  default     = true
}

variable "force_remote_runner" {
  description = "When true with remote runner attached, spawn contracts use remote runner execute_series instead of Ubuntu for scan stages."
  type        = bool
  default     = false
}

variable "runner_git_token" {
  description = "Optional git token for remote runner secret sync (clone + gh pr on runner)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "runner_git_env_secret_id" {
  description = "Existing vault secret id for runner git env when runner_git_token is empty."
  type        = string
  default     = ""
}

variable "remote_runner_secret_sync_enabled" {
  description = "When true, binds sg_remote_runner_secrets when git secret refs resolve."
  type        = bool
  default     = true
}

variable "remote_runner_generic_secret_ref_ids" {
  description = "Generic vault secret ref ids synced to remote runner (script pack env JSON)."
  type        = list(string)
  default     = []
}

variable "target_pr_repo" {
  description = "Optional fork URL for clone/push (e.g. https://github.com/you/upstream-fork). When set, notes and clone-and-pr use this instead of github_repo_url for git operations."
  type        = string
  default     = ""
}

variable "enable_llm_synthesis" {
  description = "When true, runs legacy LLM analyze-coupling-and-contexts stage before plan prep. Default false (deterministic synthesize)."
  type        = bool
  default     = false
}

variable "enable_os_enrichment" {
  description = "When true, runs llm-os-enrichment after plan_ok for advisory audience-tier prose."
  type        = bool
  default     = true
}

variable "enable_parallel_plan_prep" {
  description = "When true, architect spawns synthesize-plan, agents-md-scaffold, and fetch-repo-context runners in parallel after scan."
  type        = bool
  default     = true
}
