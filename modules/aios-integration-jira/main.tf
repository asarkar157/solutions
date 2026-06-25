terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  create_secret = trimspace(var.existing_secret_id) == "" && trimspace(var.api_token) != ""
  secret_id     = local.create_secret ? sg_secret.jira_vault[0].id : var.existing_secret_id

  # Jira Cloud "site name" is the sub-domain of the instance URL
  # (https://<site>.atlassian.net). Allow an explicit override for custom domains.
  derived_site_name = try(regex("^https?://([^./]+)\\.atlassian\\.net", var.base_url)[0], "")
  site_name         = trimspace(var.atlassian_site_name) != "" ? var.atlassian_site_name : local.derived_site_name

  # The Jira MCP sidecar (ghcr.io/appcd-dev/stackgen-guild-integration-jira) authenticates
  # from ATLASSIAN_SITE_NAME / ATLASSIAN_USER_EMAIL / ATLASSIAN_API_TOKEN *environment
  # variables*. Vault stores the credentials under base_url/email/api_token, but those keys
  # are delivered to the sidecar as /run/secrets/env.json (request headers) and are NOT read
  # by the sidecar's credential resolver. We therefore project the same values onto the env
  # the sidecar actually consumes. Without this the integration handshake/test passes but every
  # tool call fails with "Authentication credentials are missing". See README "Known issue".
  derived_env = (trimspace(var.email) != "" && trimspace(var.api_token) != "" && local.site_name != "") ? {
    ATLASSIAN_SITE_NAME  = local.site_name
    ATLASSIAN_USER_EMAIL = var.email
    ATLASSIAN_API_TOKEN  = var.api_token
  } : {}

  effective_env = merge(local.derived_env, var.env)
}

resource "terraform_data" "validate_secret_input" {
  lifecycle {
    precondition {
      condition     = (trimspace(var.api_token) != "" && trimspace(var.base_url) != "" && trimspace(var.email) != "") || trimspace(var.existing_secret_id) != ""
      error_message = "aios-integration-jira requires `existing_secret_id` or all of `base_url`, `email`, and `api_token`."
    }
    precondition {
      condition     = !(trimspace(var.api_token) != "" && trimspace(var.existing_secret_id) != "")
      error_message = "aios-integration-jira cannot accept both `api_token` and `existing_secret_id`."
    }
  }
}

resource "sg_secret" "jira_vault" {
  count = local.create_secret ? 1 : 0

  name        = "${var.integration_name}-vault"
  description = "Jira API credentials for ${var.integration_name}"
  category    = "ProjectManagement"
  subcategory = "jira"
  metadata = {
    base_url  = var.base_url
    email     = var.email
    api_token = var.api_token
  }
}

resource "sg_guild_integration" "jira" {
  name           = var.integration_name
  description    = var.description
  type           = "jira"
  scope          = var.scope
  secret_ref_ids = [local.secret_id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }

  env = length(local.effective_env) > 0 ? local.effective_env : null
}
