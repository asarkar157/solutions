variable "slack_bot_token" {
  description = "Slack Bot Token"
  type        = string
  sensitive   = true
}

variable "slack_signing_secret" {
  description = "Slack Signing Secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL"
  type        = string
  sensitive   = true
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "slack-integration"
}

variable "description" {
  type    = string
  default = "Slack ChatOps integration for incident channels, approvals, and notifications"
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
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-slack:main"
}

variable "env" {
  description = <<-EOT
    Optional map of plain-text environment variables injected into the Slack
    integration container at launch (StackGen provider >= 0.1.17). Use for
    non-sensitive overrides such as proxy URLs or feature toggles. Sensitive
    values should go through `sg_secret` and be referenced via
    `secret_ref_ids`.
  EOT
  type        = map(string)
  default     = {}
}
