terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.coralogix_api_key) != "" && trimspace(var.coralogix_base_url) != ""
  secret_id     = local.create_secret ? sg_secret.coralogix_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || (trimspace(var.coralogix_api_key) != "" && trimspace(var.coralogix_base_url) != "")
      error_message = "aios-integration-coralogix requires `existing_secret_id` or both `coralogix_api_key` and `coralogix_base_url`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && (trimspace(var.coralogix_api_key) != "" || trimspace(var.coralogix_base_url) != ""))
      error_message = "aios-integration-coralogix cannot accept `existing_secret_id` together with inline credentials."
    }
  }
}

resource "sg_secret" "coralogix_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Coralogix API credentials for ${var.integration_name}"
  category    = "Observability"
  subcategory = "coralogix"
  metadata = {
    coralogix_api_key  = var.coralogix_api_key
    coralogix_base_url = var.coralogix_base_url
  }
}

resource "sg_guild_integration" "coralogix" {
  name           = var.integration_name
  description    = var.description
  type           = "coralogix"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
