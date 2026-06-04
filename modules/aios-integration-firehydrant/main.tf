terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.api_key) != ""
  secret_id     = local.create_secret ? sg_secret.firehydrant_vault[0].id : var.existing_secret_id
  base_url      = trimspace(var.base_url) != "" ? trimspace(var.base_url) : "https://api.firehydrant.io"
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || trimspace(var.api_key) != ""
      error_message = "aios-integration-firehydrant requires `existing_secret_id` or `api_key`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && trimspace(var.api_key) != "")
      error_message = "aios-integration-firehydrant cannot accept both `api_key` and `existing_secret_id`; pass only one."
    }
  }
}

resource "sg_secret" "firehydrant_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "FireHydrant API credentials for ${var.integration_name}"
  category    = "IncidentManagement"
  subcategory = "firehydrant"
  metadata = {
    api_token = var.api_key
    base_url  = local.base_url
  }
}

resource "sg_guild_integration" "firehydrant" {
  name           = var.integration_name
  description    = var.description
  type           = "firehydrant"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
