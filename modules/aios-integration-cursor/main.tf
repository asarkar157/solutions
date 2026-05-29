terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

# =============================================================================
# Cursor Integration Module
# =============================================================================

resource "sg_secret" "cursor_vault" {
  name        = "${var.name_prefix}cursor-vault"
  description = "Cursor Cloud Agent API credentials"
  category    = "Other"
  subcategory = "cursor"
  metadata = {
    CURSOR_API_KEY = var.cursor_api_key
  }
}

resource "sg_guild_integration" "cursor" {
  name           = var.integration_name
  description    = "Cursor AI code editor integration for pair-programming agents using local Cursor indexing."
  type           = "cursor"
  scope          = "PROJECT"
  secret_ref_ids = [sg_secret.cursor_vault.id]
  enabled        = true

  image = { name = var.integration_image }

  env = length(var.env) > 0 ? var.env : null
}
