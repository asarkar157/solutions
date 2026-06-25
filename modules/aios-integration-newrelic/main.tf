terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.newrelic_api_key) != ""
  secret_id     = local.create_secret ? sg_secret.newrelic_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || trimspace(var.newrelic_api_key) != ""
      error_message = "aios-integration-newrelic requires `existing_secret_id` or `newrelic_api_key`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && trimspace(var.newrelic_api_key) != "")
      error_message = "aios-integration-newrelic cannot accept both `newrelic_api_key` and `existing_secret_id`; pass only one."
    }
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || contains(["us", "eu"], lower(trimspace(var.newrelic_region)))
      error_message = "aios-integration-newrelic `newrelic_region` must be `us` or `eu` when creating inline credentials."
    }
  }
}

resource "sg_secret" "newrelic_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "New Relic MCP credentials for ${var.integration_name}"
  category    = "Observability"
  subcategory = "newrelic"
  metadata = {
    transport        = "streamable_http"
    url              = "https://mcp.newrelic.com/mcp/"
    newrelic_api_key = var.newrelic_api_key
    newrelic_region  = lower(trimspace(var.newrelic_region))
  }
}

resource "sg_guild_integration" "newrelic" {
  name           = var.integration_name
  description    = var.description
  type           = "newrelic"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  env = length(var.env) > 0 ? var.env : null
}
