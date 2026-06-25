terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == ""
  secret_id     = local.create_secret ? sg_secret.timescaledb_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !local.create_secret || trimspace(var.dsn) != ""
      error_message = "Either provide `existing_secret_id` OR `dsn`."
    }
  }
}

resource "sg_secret" "timescaledb_vault" {
  count       = local.create_secret ? 1 : 0
  name        = "${var.integration_name}-vault"
  description = "TimescaleDB connection credentials"
  category    = "Database"
  subcategory = "timescaledb"
  metadata = {
    dsn       = var.dsn
    read_only = var.read_only
  }
}

resource "sg_guild_integration" "timescaledb" {
  name           = var.integration_name
  description    = var.description
  type           = "timescaledb"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.timescaledb_mcp_image
  }

  env = length(var.env) > 0 ? var.env : null
}
