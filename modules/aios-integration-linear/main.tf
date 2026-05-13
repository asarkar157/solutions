terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.13, < 0.2.0" }
  }
}

# =============================================================================
# Linear Integration Module (OAuth)
# =============================================================================
# Linear uses OAuth via credential_provider_id — connects directly to
# mcp.linear.app. No container image or static vault secret needed.

resource "sg_guild_integration" "linear" {
  name                   = var.integration_name
  description            = "Linear project management integration via OAuth. Connects directly to mcp.linear.app for issue tracking, project management, and workflow automation."
  type                   = "linear"
  scope                  = "PROJECT"
  enabled                = true
  credential_provider_id = var.credential_provider_id
}
