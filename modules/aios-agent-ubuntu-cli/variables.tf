variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}
variable "policy_ids" {
  type = object({
    dangerous_ops        = string
    container_shell_hitl = string
  })
}
# =============================================================================
# Self-contained integration wiring.
# =============================================================================

variable "github_secret_id" {
  description = "Optional `sg_secret` ID for a GitHub PAT. When set, the Ubuntu sandbox gets the GIT_* env vars surfaced from the Provider/github secret shape so `git clone` and `gh` are pre-authed."
  type        = string
  default     = ""
}

variable "existing_ubuntu_integration_name" {
  description = "Optional Guild integration name to share an existing Ubuntu CLI integration. When set, no internal Ubuntu integration is provisioned."
  type        = string
  default     = ""
}

variable "install_tools" {
  description = "Tools to install on first use inside the Ubuntu sandbox. Only used when this module provisions its own integration."
  type        = list(string)
  default     = ["curl", "git", "gh", "jq"]
}

variable "name_suffix" {
  description = "Optional suffix appended to agent / runbook / integration resource names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}
