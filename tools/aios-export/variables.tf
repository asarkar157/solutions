variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant to export from."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen PAT with read access to the tenant. Read-only — this tool does not write to the tenant."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "Optional project / org ID to scope the export."
  type        = string
  default     = ""
}

variable "include_drafts" {
  description = "Pass-through to sg_workflows.include_drafts. Set true to also export draft (unapproved) workflows."
  type        = bool
  default     = false
}

variable "latest_only" {
  description = "Pass-through to sg_workflows.latest_only. Set false to export every workflow version, not just the latest."
  type        = bool
  default     = true
}
