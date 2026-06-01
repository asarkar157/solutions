terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.api_token) != ""
  secret_id     = local.create_secret ? sg_secret.pagerduty_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.api_token) != "" || trimspace(var.existing_secret_id) != ""
      error_message = "aios-integration-pagerduty requires exactly one of `api_token` or `existing_secret_id`."
    }
    precondition {
      condition     = !(trimspace(var.api_token) != "" && trimspace(var.existing_secret_id) != "")
      error_message = "aios-integration-pagerduty cannot accept both `api_token` and `existing_secret_id`."
    }
  }
}

resource "sg_secret" "pagerduty_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "PagerDuty API token for ${var.integration_name}"
  category    = "IncidentManagement"
  subcategory = "pagerduty"
  metadata = {
    api_token = var.api_token
  }
}

resource "sg_guild_integration" "pagerduty" {
  name           = var.integration_name
  description    = var.description
  type           = "pagerduty"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
