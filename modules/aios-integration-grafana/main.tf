terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.grafana_token) != ""
  secret_id     = local.create_secret ? sg_secret.grafana_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.grafana_token) != "" || trimspace(var.existing_secret_id) != ""
      error_message = "aios-integration-grafana requires exactly one of `grafana_token` or `existing_secret_id` to be set."
    }
    precondition {
      condition     = !(trimspace(var.grafana_token) != "" && trimspace(var.existing_secret_id) != "")
      error_message = "aios-integration-grafana cannot accept both `grafana_token` and `existing_secret_id`; pass only one."
    }
  }
}

resource "sg_secret" "grafana_vault" {
  count = local.create_secret ? 1 : 0

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
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
