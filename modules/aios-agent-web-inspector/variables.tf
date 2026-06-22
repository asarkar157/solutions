variable "model_names" {
  description = "Ordered list of registered model names (highest preference first)."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Map of policy IDs used for agent policy attachments."
  type = object({
    dangerous_ops        = string
    container_shell_hitl = string
  })
}

# =============================================================================
# Integration wiring
# =============================================================================

variable "existing_chrome_integration_name" {
  description = "Optional existing Chrome integration name. When set, no internal Chrome integration is provisioned."
  type        = string
  default     = ""
}

variable "existing_ubuntu_integration_name" {
  description = "Optional existing Ubuntu CLI integration name. When set, no internal Ubuntu integration is provisioned."
  type        = string
  default     = ""
}

variable "grafana_integration_name" {
  description = "Optional Grafana integration name for backend metrics correlation."
  type        = string
  default     = ""
}

variable "github_integration_name" {
  description = "Optional GitHub integration name for source code context."
  type        = string
  default     = ""
}

variable "github_secret_id" {
  description = "Optional sg_secret ID for GitHub PAT (used by the Ubuntu container for git/gh)."
  type        = string
  default     = ""
}

# =============================================================================
# Chrome-specific settings
# =============================================================================

variable "chrome_allowed_domains" {
  description = "Comma-separated domain allowlist for Chrome navigation."
  type        = string
  default     = ""
}

variable "chrome_max_tabs" {
  description = "Maximum concurrent Chrome tabs."
  type        = number
  default     = 3

  validation {
    condition     = var.chrome_max_tabs >= 1 && var.chrome_max_tabs <= 10
    error_message = "chrome_max_tabs must be between 1 and 10."
  }
}

# =============================================================================
# Naming
# =============================================================================

variable "name_suffix" {
  description = "Optional suffix for all resource names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]*$", var.name_suffix))
    error_message = "name_suffix must be empty or contain only letters, digits, and hyphens."
  }
}
