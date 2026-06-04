terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.api_token) != ""
  secret_id     = local.create_secret ? sg_secret.confluence_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = (trimspace(var.api_token) != "" && trimspace(var.base_url) != "") || trimspace(var.existing_secret_id) != ""
      error_message = "aios-integration-confluence requires `existing_secret_id` or both `base_url` and `api_token`."
    }
    precondition {
      condition     = !(trimspace(var.api_token) != "" && trimspace(var.existing_secret_id) != "")
      error_message = "aios-integration-confluence cannot accept both `api_token` and `existing_secret_id`."
    }
  }
}

resource "sg_secret" "confluence_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Confluence API credentials for ${var.integration_name}"
  category    = "KnowledgeBase"
  subcategory = "confluence"
  metadata = {
    base_url  = var.base_url
    email     = var.email
    api_token = var.api_token
  }
}

resource "sg_guild_integration" "confluence" {
  name           = var.integration_name
  description    = var.description
  type           = "confluence"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
