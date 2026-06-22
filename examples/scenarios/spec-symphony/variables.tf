variable "stackgen_url" {
  type = string
}

variable "stackgen_token" {
  type      = string
  sensitive = true
}

variable "stackgen_project_id" {
  type    = string
  default = ""
}

variable "openai_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "anthropic_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "gemini_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "github_token" {
  description = "GitHub PAT with repo scope for runner clone/PR."
  type        = string
  sensitive   = true
}

variable "target_repository_full_name" {
  description = "Default GitHub repo (owner/name) for webhook test scripts and trigger-webhook.sh --from-tofu-output."
  type        = string
  default     = ""
}

variable "linear_credential_provider_id" {
  description = "Linear OAuth credential provider ID (alternative to linear_api_key for linear-product-spec + linear-spec-implement workflows)."
  type        = string
  default     = ""
}

variable "linear_api_key" {
  description = "Linear personal API key (lin_api_…). Creates aios-integration-linear vault secret when set."
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_linear_product_spec_workflow" {
  type    = bool
  default = true
}

variable "enable_linear_implement_workflow" {
  type    = bool
  default = true
}

variable "linear_implement_engine" {
  type    = string
  default = "cursor_cli"

  validation {
    condition     = contains(["shell", "cursor_cli"], var.linear_implement_engine)
    error_message = "linear_implement_engine must be shell or cursor_cli."
  }
}

variable "sdd_framework" {
  type    = string
  default = "auto"
}

variable "change_type" {
  type    = string
  default = "brownfield"
}

variable "create_remote_runner" {
  type    = bool
  default = true
}

variable "build_runner_image" {
  type    = bool
  default = true
}

variable "power_pack_refs" {
  type    = map(string)
  default = {}
}

variable "implement_engine" {
  type    = string
  default = "shell"

  validation {
    condition     = contains(["shell", "cursor_cli"], var.implement_engine)
    error_message = "implement_engine must be shell or cursor_cli."
  }
}

variable "cursor_api_key" {
  description = "Required when implement_engine=cursor_cli or linear_implement_engine=cursor_cli."
  type        = string
  sensitive   = true
  default     = ""
}
