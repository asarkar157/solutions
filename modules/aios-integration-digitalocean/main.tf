terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.digitalocean_token) != ""
  secret_id     = local.create_secret ? sg_secret.digitalocean_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || trimspace(var.digitalocean_token) != ""
      error_message = "aios-integration-digitalocean requires `existing_secret_id` or `digitalocean_token`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && trimspace(var.digitalocean_token) != "")
      error_message = "aios-integration-digitalocean cannot accept both `digitalocean_token` and `existing_secret_id`; pass only one."
    }
  }
}

resource "sg_secret" "digitalocean_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "DigitalOcean API credentials for ${var.integration_name}"
  category    = "Cloud"
  subcategory = "digitalocean"
  metadata = {
    digitalocean_token = var.digitalocean_token
  }
}

resource "sg_guild_integration" "digitalocean" {
  name           = var.integration_name
  description    = var.description
  type           = "digitalocean"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
