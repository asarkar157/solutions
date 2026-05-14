terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.17, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.slack_bot_token) != ""
  secret_id     = local.create_secret ? sg_secret.slack_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.slack_bot_token) != "" || trimspace(var.existing_secret_id) != ""
      error_message = "aios-integration-slack requires exactly one of `slack_bot_token` or `existing_secret_id` to be set."
    }
    precondition {
      condition     = !(trimspace(var.slack_bot_token) != "" && trimspace(var.existing_secret_id) != "")
      error_message = "aios-integration-slack cannot accept both `slack_bot_token` and `existing_secret_id`; pass only one."
    }
  }
}

resource "sg_secret" "slack_vault" {
  count = local.create_secret ? 1 : 0

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
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
