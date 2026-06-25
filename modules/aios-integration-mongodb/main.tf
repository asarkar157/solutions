terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == ""
  secret_id     = local.create_secret ? sg_secret.mongodb_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !local.create_secret || trimspace(var.connection_string) != ""
      error_message = "Either provide `existing_secret_id` OR `connection_string`."
    }
  }
}

resource "sg_secret" "mongodb_vault" {
  count       = local.create_secret ? 1 : 0
  name        = "${var.integration_name}-vault"
  description = "MongoDB connection credentials"
  category    = "Database"
  subcategory = "mongodb"
  metadata = {
    connection_string = var.connection_string
  }
}

resource "sg_guild_integration" "mongodb" {
  name           = var.integration_name
  description    = var.description
  type           = "mongodb"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.mongodb_mcp_image
  }

  env = length(var.env) > 0 ? var.env : null
}
