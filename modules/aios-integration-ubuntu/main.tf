terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.0" }
  }
}

# =============================================================================
# Ubuntu CLI Integration Module (Generic MCP Shell)
# =============================================================================

resource "sg_guild_integration" "ubuntu_cli" {
  name        = var.integration_name
  description = "Generic Ubuntu CLI MCP shell for OS-level diagnostics: curl, ping, dig, journalctl, top, df, etc."
  type        = "mcp"
  scope       = "PROJECT"
  enabled     = true

  image = { name = var.integration_image }
}
