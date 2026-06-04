terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.datadog_api_key) != ""
  secret_id     = local.create_secret ? sg_secret.datadog_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.datadog_api_key) != "" || trimspace(var.existing_secret_id) != ""
      error_message = "aios-integration-datadog requires exactly one of `datadog_api_key` (+ `datadog_app_key`) or `existing_secret_id`."
    }
    precondition {
      condition     = !(trimspace(var.datadog_api_key) != "" && trimspace(var.existing_secret_id) != "")
      error_message = "aios-integration-datadog cannot accept both API keys and `existing_secret_id`; pass only one."
    }
  }
}

resource "sg_secret" "datadog_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Datadog MCP credentials for ${var.integration_name}"
  category    = "Observability"
  subcategory = "datadog"
  metadata = {
    transport          = "streamable_http"
    url                = "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp"
    dd_api_key         = var.datadog_api_key
    dd_application_key = var.datadog_app_key
    dd_site            = var.datadog_site
  }
}

resource "sg_guild_integration" "datadog" {
  name           = var.integration_name
  description    = var.description
  type           = "datadog"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled
}
