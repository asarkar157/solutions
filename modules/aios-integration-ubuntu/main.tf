terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.18, < 0.2.0" }
  }
}

# =============================================================================
# Ubuntu CLI Integration Module (Generic MCP Shell)
# =============================================================================

locals {
  # Build the INSTALL_TOOLS env var from the list (comma-separated).
  install_tools_env = length(var.install_tools) > 0 ? {
    INSTALL_TOOLS = join(",", var.install_tools)
  } : {}
  ubuntu_env = merge(local.install_tools_env, var.env_vars)
}

resource "sg_guild_integration" "ubuntu_cli" {
  name           = var.integration_name
  description    = "Generic Ubuntu CLI MCP shell for OS-level diagnostics: curl, ping, dig, journalctl, top, df, etc."
  type           = "mcp"
  scope          = "PROJECT"
  secret_ref_ids = var.secret_ref_ids
  enabled        = true

  image = { name = var.integration_image }

  env = length(local.ubuntu_env) > 0 ? local.ubuntu_env : null
}
