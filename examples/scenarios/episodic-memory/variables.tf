variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant (no trailing slash)."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen personal access token."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "Optional StackGen project / org ID."
  type        = string
  default     = ""
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

variable "agent_budget_usd" {
  description = "Daily USD budget for the memory-tutor agent."
  type        = number
  default     = 5
}
