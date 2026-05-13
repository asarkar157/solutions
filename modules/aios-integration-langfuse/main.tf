terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.17, < 0.2.0" }
  }
}

# =============================================================================
# Langfuse Integration Module
# =============================================================================

resource "sg_secret" "langfuse_vault" {
  name        = "${var.integration_name}-vault"
  description = "Langfuse API credentials for ${var.integration_name}"
  category    = "Observability"
  subcategory = "langfuse"
  metadata = {
    public_key = var.langfuse_public_key
    secret_key = var.langfuse_secret_key
    host       = var.langfuse_host
  }
}

resource "sg_guild_integration" "langfuse" {
  name           = var.integration_name
  description    = var.description
  type           = "langfuse"
  scope          = var.scope
  secret_ref_ids = [sg_secret.langfuse_vault.id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = var.env
}
