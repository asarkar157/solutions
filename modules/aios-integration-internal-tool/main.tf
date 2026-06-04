terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.base_url) != ""
  secret_id     = local.create_secret ? sg_secret.internal_tool_vault[0].id : var.existing_secret_id
  auth_header   = trimspace(var.api_key) != "" ? "Bearer ${var.api_key}" : ""
  secret_metadata = merge(
    { base_url = var.base_url },
    local.auth_header != "" ? { auth_header = local.auth_header } : {},
  )
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || trimspace(var.base_url) != ""
      error_message = "aios-integration-internal-tool requires `existing_secret_id` or `base_url`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && (trimspace(var.base_url) != "" || trimspace(var.api_key) != ""))
      error_message = "aios-integration-internal-tool cannot accept `existing_secret_id` together with inline `base_url` / `api_key`."
    }
  }
}

resource "sg_secret" "internal_tool_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Internal tooling REST API credentials for ${var.integration_name}"
  category    = "RestAPI"
  subcategory = "restapi"
  metadata    = local.secret_metadata
}

resource "sg_guild_integration" "internal_tool" {
  name           = var.integration_name
  description    = var.description
  type           = "restapi"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
