terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == ""
  secret_id     = local.create_secret ? sg_secret.mysql_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !local.create_secret || (trimspace(var.mysql_host) != "" && trimspace(var.mysql_password) != "")
      error_message = "Either provide `existing_secret_id` OR provide both `mysql_host` and `mysql_password`."
    }
  }
}

resource "sg_secret" "mysql_vault" {
  count       = local.create_secret ? 1 : 0
  name        = "${var.integration_name}-vault"
  description = "MySQL connection credentials"
  category    = "Database"
  subcategory = "mysql"
  metadata = {
    host     = var.mysql_host
    port     = tostring(var.mysql_port)
    database = var.mysql_database
    user     = var.mysql_user
    password = var.mysql_password
  }
}

resource "sg_guild_integration" "mysql" {
  name           = var.integration_name
  description    = var.description
  type           = "mysql"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.mysql_mcp_image
  }

  env = length(var.env) > 0 ? var.env : null
}
