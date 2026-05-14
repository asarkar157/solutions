variable "slack_bot_token" {
  description = <<-EOT
    Slack Bot Token. When set, this module creates a fresh `sg_secret` of
    category `Notification`, subcategory `slack` and binds the integration
    to it. Mutually exclusive with `existing_secret_id` — set exactly one.
  EOT
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_signing_secret" {
  description = "Slack Signing Secret. Only used when creating a fresh secret (i.e. `existing_secret_id` is empty)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL. Only used when creating a fresh secret (i.e. `existing_secret_id` is empty)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = <<-EOT
    Optional ID of a pre-existing `sg_secret` holding Slack credentials. When
    set, this module skips creating its own secret and binds the Slack
    integration directly to the supplied secret. Use this when several agent
    modules share a single tenant-level Slack workspace. Mutually exclusive
    with `slack_bot_token` — set exactly one.
  EOT
  type        = string
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
