terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.9, < 0.2.0" }
  }
}

resource "sg_secret" "clickhouse_vault" {
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
  secret_ref_ids = [sg_secret.clickhouse_vault.id]
  enabled        = var.enabled

  image = {
    name = var.clickhouse_mcp_image
  }
}
