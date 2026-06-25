terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == ""
  secret_id     = local.create_secret ? sg_secret.elasticsearch_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !local.create_secret || (trimspace(var.es_url) != "" && trimspace(var.es_api_key) != "")
      error_message = "Either provide `existing_secret_id` OR both `es_url` and `es_api_key`."
    }
  }
}

resource "sg_secret" "elasticsearch_vault" {
  count       = local.create_secret ? 1 : 0
  name        = "${var.integration_name}-vault"
  description = "Elasticsearch cluster credentials"
  category    = "Database"
  subcategory = "elasticsearch"
  metadata = {
    es_url             = var.es_url
    es_api_key         = var.es_api_key
    es_ssl_skip_verify = var.es_ssl_skip_verify
  }
}

resource "sg_guild_integration" "elasticsearch" {
  name           = var.integration_name
  description    = var.description
  type           = "elasticsearch"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.elasticsearch_mcp_image
  }

  env = length(var.env) > 0 ? var.env : null
}
