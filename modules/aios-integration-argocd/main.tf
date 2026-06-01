terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  has_token_creds = trimspace(var.server_url) != "" && trimspace(var.auth_token) != ""
  has_basic_creds = trimspace(var.server_url) != "" && trimspace(var.username) != "" && trimspace(var.password) != ""
  create_secret   = trimspace(var.existing_secret_id) == "" && (local.has_token_creds || local.has_basic_creds)
  secret_id       = local.create_secret ? sg_secret.argocd_vault[0].id : var.existing_secret_id
  secret_metadata = merge(
    { server_url = var.server_url },
    trimspace(var.auth_token) != "" ? { auth_token = var.auth_token } : {},
    trimspace(var.username) != "" ? { username = var.username } : {},
    trimspace(var.password) != "" ? { password = var.password } : {},
  )
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || local.has_token_creds || local.has_basic_creds
      error_message = "aios-integration-argocd requires `existing_secret_id` or `server_url` with `auth_token` (preferred) or both `username` and `password`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && (trimspace(var.server_url) != "" || trimspace(var.auth_token) != "" || trimspace(var.username) != "" || trimspace(var.password) != ""))
      error_message = "aios-integration-argocd cannot accept `existing_secret_id` together with inline credentials."
    }
  }
}

resource "sg_secret" "argocd_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Argo CD API credentials for ${var.integration_name}"
  category    = "CICD"
  subcategory = "argocd"
  metadata    = local.secret_metadata
}

resource "sg_guild_integration" "argocd" {
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
