terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  token         = trimspace(var.private_token) != "" ? var.private_token : var.api_token
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.base_url) != "" && trimspace(local.token) != ""
  secret_id     = local.create_secret ? sg_secret.gitlab_vault[0].id : var.existing_secret_id
  secret_metadata = merge(
    { base_url = var.base_url },
    trimspace(var.private_token) != "" ? { private_token = var.private_token } : {},
    trimspace(var.api_token) != "" && trimspace(var.private_token) == "" ? { api_token = var.api_token } : {},
  )
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || (trimspace(var.base_url) != "" && trimspace(local.token) != "")
      error_message = "aios-integration-gitlab requires `existing_secret_id` or both `base_url` and `private_token` (or `api_token`)."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && (trimspace(var.base_url) != "" || trimspace(local.token) != ""))
      error_message = "aios-integration-gitlab cannot accept `existing_secret_id` together with inline credentials."
    }
    precondition {
      condition     = !(trimspace(var.private_token) != "" && trimspace(var.api_token) != "")
      error_message = "aios-integration-gitlab cannot accept both `private_token` and `api_token`; pass only one."
    }
  }
}

resource "sg_secret" "gitlab_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "GitLab API credentials for ${var.integration_name}"
  category    = "SCM"
  subcategory = "gitlab"
  metadata    = local.secret_metadata
}

resource "sg_guild_integration" "gitlab" {
  name           = var.integration_name
  description    = var.description
  type           = "gitlab"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
