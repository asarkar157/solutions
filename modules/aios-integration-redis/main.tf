terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == ""
  secret_id     = local.create_secret ? sg_secret.redis_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !local.create_secret || trimspace(var.url) != ""
      error_message = "Either provide `existing_secret_id` OR `url`."
    }
  }
}

resource "sg_secret" "redis_vault" {
  count       = local.create_secret ? 1 : 0
  name        = "${var.integration_name}-vault"
  description = "Redis connection credentials"
  category    = "Database"
  subcategory = "redis"
  metadata = {
    url = var.url
  }
}

resource "sg_guild_integration" "redis" {
  name           = var.integration_name
  description    = var.description
  type           = "redis"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.redis_mcp_image
  }

  env = length(var.env) > 0 ? var.env : null
}
