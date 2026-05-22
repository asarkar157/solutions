terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.19, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == ""
  secret_id     = local.create_secret ? sg_secret.clickhouse_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !local.create_secret || (trimspace(var.clickhouse_host) != "" && trimspace(var.clickhouse_password) != "")
      error_message = "Either provide `existing_secret_id` OR provide both `clickhouse_host` and `clickhouse_password` so this module can provision the `sg_secret`."
    }
  }
}

resource "sg_secret" "clickhouse_vault" {
  count       = local.create_secret ? 1 : 0
  name        = "${var.integration_name}-vault"
  description = "ClickHouse Cloud connection credentials"
  category    = "CloudProvider"
  subcategory = "clickhouse"
  metadata = {
    CLICKHOUSE_HOST     = var.clickhouse_host
    CLICKHOUSE_USER     = var.clickhouse_user
    CLICKHOUSE_PASSWORD = var.clickhouse_password
    CLICKHOUSE_PORT     = tostring(var.clickhouse_port)
    CLICKHOUSE_DATABASE = var.clickhouse_database
    CLICKHOUSE_SECURE   = "true"
  }
}

resource "sg_guild_integration" "clickhouse" {
  name           = var.integration_name
  description    = var.description
  type           = "clickhouse"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.clickhouse_mcp_image
  }

  env = length(var.env) > 0 ? var.env : null
}
