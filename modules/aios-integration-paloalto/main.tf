terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  has_api_key_creds = trimspace(var.management_url) != "" && trimspace(var.api_key) != ""
  has_basic_creds   = trimspace(var.management_url) != "" && trimspace(var.username) != "" && trimspace(var.password) != ""
  create_secret     = trimspace(var.existing_secret_id) == "" && (local.has_api_key_creds || local.has_basic_creds)
  secret_id         = local.create_secret ? sg_secret.paloalto_vault[0].id : var.existing_secret_id

  secret_metadata = merge(
    { management_url = var.management_url },
    trimspace(var.api_key) != "" ? { api_key = var.api_key } : {},
    trimspace(var.username) != "" ? { username = var.username } : {},
    trimspace(var.password) != "" ? { password = var.password } : {},
  )
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || local.has_api_key_creds || local.has_basic_creds
      error_message = "aios-integration-paloalto requires `existing_secret_id` or `management_url` with `api_key` (preferred) or both `username` and `password`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && (trimspace(var.management_url) != "" || trimspace(var.api_key) != "" || trimspace(var.username) != "" || trimspace(var.password) != ""))
      error_message = "aios-integration-paloalto cannot accept `existing_secret_id` together with inline credentials."
    }
  }
}

resource "sg_secret" "paloalto_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Palo Alto Networks PAN-OS credentials for ${var.integration_name}"
  category    = "Security"
  subcategory = "paloalto"
  metadata    = local.secret_metadata
}

resource "sg_guild_integration" "paloalto" {
  name           = var.integration_name
  description    = var.description
  type           = var.integration_type
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
