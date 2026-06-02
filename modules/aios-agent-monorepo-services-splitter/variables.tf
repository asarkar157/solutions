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
    boundary_scan_max_llm_calls           = optional(number)
    boundary_scan_max_tool_iterations     = optional(number)
    boundary_scan_timeout_seconds         = optional(number)
    guidance_pr_max_llm_calls             = optional(number)
    guidance_pr_max_tool_iterations       = optional(number)
    guidance_pr_timeout_seconds           = optional(number)
    scaffold_services_max_llm_calls       = optional(number)
    scaffold_services_max_tool_iterations = optional(number)
    scaffold_services_timeout_seconds     = optional(number)
    extract_pr_max_llm_calls              = optional(number)
    extract_pr_max_tool_iterations        = optional(number)
    extract_pr_timeout_seconds            = optional(number)
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
