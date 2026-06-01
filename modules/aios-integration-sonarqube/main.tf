terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.20, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.server_url) != "" && trimspace(var.token) != ""
  secret_id     = local.create_secret ? sg_secret.sonarqube_vault[0].id : var.existing_secret_id
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || (trimspace(var.server_url) != "" && trimspace(var.token) != "")
      error_message = "aios-integration-sonarqube requires `existing_secret_id` or both `server_url` and `token`."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && (trimspace(var.server_url) != "" || trimspace(var.token) != ""))
      error_message = "aios-integration-sonarqube cannot accept `existing_secret_id` together with inline credentials."
    }
  }
}

resource "sg_secret" "sonarqube_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "SonarQube API credentials for ${var.integration_name}"
  category    = "Quality"
  subcategory = "sonarqube"
  metadata = {
    server_url = var.server_url
    token      = var.token
  }
}

resource "sg_guild_integration" "sonarqube" {
  name           = var.integration_name
  description    = var.description
  type           = "sonarqube"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(var.env) > 0 ? var.env : null
}
