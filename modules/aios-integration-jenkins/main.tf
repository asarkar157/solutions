terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  has_inline_creds = trimspace(var.jenkins_base_url) != "" && trimspace(var.jenkins_username) != "" && trimspace(var.jenkins_token) != ""
  create_secret    = trimspace(var.existing_secret_id) == "" && local.has_inline_creds
  secret_id        = local.create_secret ? sg_secret.jenkins_vault[0].id : var.existing_secret_id
  secret_metadata = merge(
    {
      jenkins_base_url = var.jenkins_base_url
      jenkins_username = var.jenkins_username
      jenkins_token    = var.jenkins_token
    },
    trimspace(var.jenkins_mcp_url) != "" ? { jenkins_mcp_url = var.jenkins_mcp_url } : {}
  )
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = trimspace(var.existing_secret_id) != "" || local.has_inline_creds
      error_message = "aios-integration-jenkins requires either `existing_secret_id` or all of `jenkins_base_url`, `jenkins_username`, and `jenkins_token` to be set."
    }
    precondition {
      condition     = !(trimspace(var.existing_secret_id) != "" && (trimspace(var.jenkins_base_url) != "" || trimspace(var.jenkins_username) != "" || trimspace(var.jenkins_token) != ""))
      error_message = "aios-integration-jenkins cannot accept both `existing_secret_id` and inline credentials; pass only one."
    }
  }
}

resource "sg_secret" "jenkins_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Jenkins API credentials for ${var.integration_name}"
  category    = "CICD"
  subcategory = "jenkins"
  metadata    = local.secret_metadata
}

resource "sg_guild_integration" "jenkins" {
  name           = var.integration_name
  description    = var.description
  type           = "jenkins"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled
}
