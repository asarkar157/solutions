terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == ""
  secret_id     = local.create_secret ? sg_secret.mssql_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !local.create_secret || (trimspace(var.mssql_host) != "" && trimspace(var.mssql_password) != "")
      error_message = "Either provide `existing_secret_id` OR provide both `mssql_host` and `mssql_password`."
    }
  }
}

resource "sg_secret" "mssql_vault" {
  count       = local.create_secret ? 1 : 0
  name        = "${var.integration_name}-vault"
  description = "Microsoft SQL Server credentials"
  category    = "Database"
  subcategory = "mssql"
  metadata = {
    host     = var.mssql_host
    port     = tostring(var.mssql_port)
    database = var.mssql_database
    user     = var.mssql_user
    password = var.mssql_password
  }
}

resource "sg_guild_integration" "mssql" {
  name           = var.integration_name
  description    = var.description
  type           = "mssql"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.mssql_mcp_image
  }

  env = length(var.env) > 0 ? var.env : null
}
