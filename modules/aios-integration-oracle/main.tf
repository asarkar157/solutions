terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == ""
  secret_id     = local.create_secret ? sg_secret.oracle_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !local.create_secret || (trimspace(var.connection_string) != "" && trimspace(var.password) != "")
      error_message = "Either provide `existing_secret_id` OR `connection_string` and `password`."
    }
  }
}

resource "sg_secret" "oracle_vault" {
  count       = local.create_secret ? 1 : 0
  name        = "${var.integration_name}-vault"
  description = "Oracle Database credentials"
  category    = "Database"
  subcategory = "oracle"
  metadata = {
    connection_string = var.connection_string
    username          = var.username
    password          = var.password
    wallet            = var.wallet
    use_oci           = var.use_oci
  }
}

resource "sg_guild_integration" "oracle" {
  name           = var.integration_name
  description    = var.description
  type           = "oracle"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.oracle_mcp_image
  }

  env = length(var.env) > 0 ? var.env : null
}
