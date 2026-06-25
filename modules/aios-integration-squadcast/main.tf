terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  squadcast_region = lower(trimspace(var.squadcast_region))
  create_secret    = trimspace(var.existing_secret_id) == "" && trimspace(var.squadcast_refresh_token) != ""
  secret_id        = local.create_secret ? sg_secret.squadcast_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || trimspace(var.squadcast_refresh_token) != ""
      error_message = "aios-integration-squadcast requires `existing_secret_id` or `squadcast_refresh_token`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && trimspace(var.squadcast_refresh_token) != "")
      error_message = "aios-integration-squadcast cannot accept both `squadcast_refresh_token` and `existing_secret_id`; pass only one."
    }
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || contains(["us", "eu"], local.squadcast_region)
      error_message = "aios-integration-squadcast `squadcast_region` must be `us` or `eu` when creating inline credentials."
    }
  }
}

resource "sg_secret" "squadcast_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "SquadCast API credentials for ${var.integration_name}"
  category    = "IncidentManagement"
  subcategory = "squadcast"
  metadata = {
    squadcast_refresh_token = var.squadcast_refresh_token
    squadcast_region        = local.squadcast_region
  }
}

resource "sg_guild_integration" "squadcast" {
  name           = var.integration_name
  description    = var.description
  type           = "squadcast"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
