terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.17, < 0.2.0" }
  }
}

# =============================================================================
# Grafana Integration Module
# =============================================================================

resource "sg_secret" "grafana_vault" {
  name        = "${var.integration_name}-vault"
  description = "Grafana API credentials for ${var.integration_name}"
  category    = "Observability"
  subcategory = "grafana"
  metadata = {
    server = var.grafana_server
    token  = var.grafana_token
  }
}

resource "sg_guild_integration" "grafana" {
  name           = var.integration_name
  description    = var.description
  type           = "grafana"
  scope          = var.scope
  secret_ref_ids = [sg_secret.grafana_vault.id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
