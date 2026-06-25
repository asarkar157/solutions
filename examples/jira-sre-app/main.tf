# =============================================================================
# Example: jira-sre-app
# =============================================================================
# End-to-end Jira wiring for the StackGen SRE Copilot app:
#
#   1. aios-integration-jira      -> creates the Guild "jira" integration
#                                    (Vault secret with base_url/email/api_token
#                                    + sg_guild_integration sidecar).
#   2. aios-sre-app-bindings      -> binds that integration onto the installed
#                                    stackgen-sre-app via sg_app (PUT /api/v1/apps/sre),
#                                    so the SRE investigator can actually call Jira.
#
# Step 2 is the piece that is missing when you only add Jira under
# Settings -> Integrations: the workspace integration exists, but the SRE app
# install never references it until sg_app.integrations includes it.
#
# See ./README.md for the in-depth verification (tofu validate + live Jira API).

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
      # sg_app (SRE app binding) requires provider >= 0.1.26.
      version = ">= 0.1.27, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

# ---------------------------------------------------------------------------
# 1. Workspace/project Jira integration (credentials -> Vault -> sidecar).
# ---------------------------------------------------------------------------
module "jira_integration" {
  source = "../../modules/aios-integration-jira"

  integration_name = var.integration_name
  scope            = var.integration_scope

  # Either pass credentials (creates the Vault secret) ...
  base_url  = var.jira_base_url
  email     = var.jira_email
  api_token = var.jira_api_token

  # ... or reference a pre-existing Vault secret instead (leave creds blank):
  existing_secret_id = var.existing_jira_secret_id
}

# ---------------------------------------------------------------------------
# 2. Bind the Jira integration onto the installed SRE app.
#    Requires stackgen-sre-app to already be installed in the target org.
# ---------------------------------------------------------------------------
module "sre_app_bindings" {
  count  = var.bind_to_sre_app ? 1 : 0
  source = "../../modules/aios-sre-app-bindings"

  app_name = var.sre_app_name

  # Union with whatever the SRE app already has (e.g. Datadog from onboarding)
  # so this apply only *adds* Jira and never drops existing bindings.
  merge_existing_app_integrations = true
  enable_discovery_bootstrap      = false

  integration_names = [module.jira_integration.integration_name]
  alert_webhooks    = []
}
