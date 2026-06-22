terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
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
  install_pip_packages_env = length(var.pip_packages) > 0 ? {
    INSTALL_PIP_PACKAGES = join(",", var.pip_packages)
  } : {}
  # Provider/github secrets use vault keys token/git_host/git_username; mcp-shell maps
  # them via MCP_SECRET_MAP (see stackgen-guild cmd/integrations/ubuntu-cli/entrypoint.sh).
  # Terraform can set the same map so pods work before the image entrypoint ships.
  ubuntu_secret_map_env = length(var.secret_ref_ids) > 0 ? {
    MCP_SECRET_MAP        = "GIT_TOKEN=token,GH_TOKEN=token,GITHUB_TOKEN=token,GIT_HOST=git_host,GIT_USERNAME=git_username"
    MCP_SHELL_SECRET_CLIS = "gh,git,curl"
  } : {}
  ubuntu_env = merge(local.install_tools_env, local.install_pip_packages_env, local.ubuntu_secret_map_env, var.env_vars)
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
