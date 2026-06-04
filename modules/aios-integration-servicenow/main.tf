terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.instance_url) != "" && trimspace(var.username) != "" && trimspace(var.password) != ""
  secret_id     = local.create_secret ? sg_secret.servicenow_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || (trimspace(var.instance_url) != "" && trimspace(var.username) != "" && trimspace(var.password) != "")
      error_message = "aios-integration-servicenow requires `existing_secret_id` or all of `instance_url`, `username`, and `password`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && (trimspace(var.instance_url) != "" || trimspace(var.username) != "" || trimspace(var.password) != ""))
      error_message = "aios-integration-servicenow cannot accept `existing_secret_id` together with inline credentials."
    }
  }
}

resource "sg_secret" "servicenow_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "ServiceNow basic-auth credentials for ${var.integration_name}"
  category    = "ITSM"
  subcategory = "servicenow"
  metadata = {
    # Guild servicenow container maps base_url → SERVICENOW_INSTANCE_URL
    base_url = var.instance_url
    username = var.username
    password = var.password
  }
}

resource "sg_guild_integration" "servicenow" {
  name           = var.integration_name
  description    = var.description
  type           = "servicenow"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
