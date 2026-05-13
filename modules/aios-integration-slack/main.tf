terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.13, < 0.2.0" }
  }
}

resource "sg_secret" "slack_vault" {
  name        = "${var.integration_name}-vault"
  description = "Slack Bot Token for MCP integration"
  category    = "Notification"
  subcategory = "slack"
  metadata = {
    webhook_url          = var.slack_webhook_url
    slack_bot_token      = var.slack_bot_token
    slack_signing_secret = var.slack_signing_secret
  }
}

resource "sg_guild_integration" "slack" {
  name           = var.integration_name
  description    = var.description
  type           = "slack"
  scope          = var.scope
  secret_ref_ids = [sg_secret.slack_vault.id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }
}
