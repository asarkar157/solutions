terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = "~> 0.1.0" }
  }
}

resource "sg_secret" "github_vault" {
  name        = "${var.integration_name}-vault"
  description = "GitHub personal access token for SCM integration"
  category    = "SCM"
  subcategory = "github"
  metadata = {
    provider = "github"
    token    = var.github_token
  }
}

resource "sg_guild_integration" "github" {
  name           = var.integration_name
  description    = var.description
  type           = "github"
  scope          = var.scope
  secret_ref_ids = [sg_secret.github_vault.id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }
}
