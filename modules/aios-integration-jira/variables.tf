variable "base_url" {
  description = "Jira Cloud instance URL (for example, https://yourorg.atlassian.net). Required when creating a secret."
  type        = string
  default     = ""
}

variable "email" {
  description = "Atlassian account email for Jira API token auth. Required when creating a secret."
  type        = string
  default     = ""
}

variable "api_token" {
  description = "Jira API token. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Existing sg_secret ID with `base_url`, `email`, and `api_token` metadata."
  type        = string
  default     = ""
}

variable "integration_name" {
  description = "Guild integration name."
  type        = string
  default     = "jira-integration"
}

variable "description" {
  description = "Guild integration description."
  type        = string
  default     = "Jira integration for issue triage, sprint context, and ticket updates."
}

variable "scope" {
  description = "Guild integration scope."
  type        = string
  default     = "PROJECT"
}

variable "enabled" {
  description = "Whether the Guild integration is enabled."
  type        = bool
  default     = true
}

variable "integration_image" {
  description = "Container image for the Jira MCP sidecar."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-jira:main"
}

variable "atlassian_site_name" {
  description = <<-EOT
    Override for the Jira Cloud site name (the `<site>` in https://<site>.atlassian.net),
    used to populate ATLASSIAN_SITE_NAME for the sidecar. Leave empty to derive it from
    `base_url`. Set this when `base_url` is a custom domain that the module cannot parse.
  EOT
  type        = string
  default     = ""
}

variable "env" {
  description = <<-EOT
    Additional environment variables for the Jira integration sidecar. Merged on top of the
    ATLASSIAN_SITE_NAME / ATLASSIAN_USER_EMAIL / ATLASSIAN_API_TOKEN values the module derives
    from base_url/email/api_token, so callers can override them when needed.
  EOT
  type        = map(string)
  default     = {}
}
