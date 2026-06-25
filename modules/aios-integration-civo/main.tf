terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.civo_api_key) != ""
  secret_id     = local.create_secret ? sg_secret.civo_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || trimspace(var.civo_api_key) != ""
      error_message = "aios-integration-civo requires `existing_secret_id` or `civo_api_key`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && trimspace(var.civo_api_key) != "")
      error_message = "aios-integration-civo cannot accept both `civo_api_key` and `existing_secret_id`; pass only one."
    }
  }
}

resource "sg_secret" "civo_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Civo API credentials for ${var.integration_name}"
  category    = "Cloud"
  subcategory = "civo"
  metadata = {
    civo_api_key = var.civo_api_key
  }
}

resource "sg_guild_integration" "civo" {
  name           = var.integration_name
  description    = var.description
  type           = "civo"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
