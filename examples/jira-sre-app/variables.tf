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
  description = "Optional StackGen project / org ID for project-scoped Guild resources."
  type        = string
  default     = ""
}

# --- Jira credentials (create a new Vault secret) ---------------------------

variable "jira_base_url" {
  description = "Jira Cloud instance URL, e.g. https://yourorg.atlassian.net. Leave blank when using existing_jira_secret_id."
  type        = string
  default     = ""
}

variable "jira_email" {
  description = "Atlassian account email for API-token auth. Leave blank when using existing_jira_secret_id."
  type        = string
  default     = ""
}

variable "jira_api_token" {
  description = "Jira API token. Mutually exclusive with existing_jira_secret_id."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_jira_secret_id" {
  description = "Existing sg_secret ID holding base_url/email/api_token metadata. Mutually exclusive with the credential variables above."
  type        = string
  default     = ""
}

# --- Integration / app wiring ----------------------------------------------

variable "integration_name" {
  description = "Guild integration name to create for Jira."
  type        = string
  default     = "jira-integration"
}

variable "integration_scope" {
  description = "Guild integration scope (PROJECT or WORKSPACE)."
  type        = string
  default     = "PROJECT"
}

variable "bind_to_sre_app" {
  description = "When true, bind the Jira integration onto the installed stackgen-sre-app via sg_app. The SRE app must already be installed in the org."
  type        = bool
  default     = true
}

variable "sre_app_name" {
  description = "Deployment-catalog slug for the SRE Copilot app install."
  type        = string
  default     = "sre"
}
