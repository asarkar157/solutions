terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == ""
  secret_id     = local.create_secret ? sg_secret.pinecone_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !local.create_secret || trimspace(var.api_key) != ""
      error_message = "Either provide `existing_secret_id` OR `api_key`."
    }
  }
}

resource "sg_secret" "pinecone_vault" {
  count       = local.create_secret ? 1 : 0
  name        = "${var.integration_name}-vault"
  description = "Pinecone API credentials"
  category    = "Database"
  subcategory = "pinecone"
  metadata = {
    api_key = var.api_key
  }
}

resource "sg_guild_integration" "pinecone" {
  name           = var.integration_name
  description    = var.description
  type           = "pinecone"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.pinecone_mcp_image
  }

  env = length(var.env) > 0 ? var.env : null
}
