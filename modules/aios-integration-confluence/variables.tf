variable "base_url" {
  description = "Confluence Cloud base URL (e.g. https://yourorg.atlassian.net/wiki). Required when creating a secret."
  type        = string
  default     = ""
}

variable "email" {
  description = "Atlassian account email for API token auth."
  type        = string
  default     = ""
}

variable "api_token" {
  description = "Confluence API token. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "integration_name" {
  type    = string
  default = "confluence-integration"
}

variable "description" {
  type    = string
  default = "Confluence integration for operational runbooks and postmortem templates."
}

variable "scope" {
  type    = string
  default = "PROJECT"
}

variable "enabled" {
  type    = bool
  default = true
}

variable "integration_image" {
  type    = string
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-confluence:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
