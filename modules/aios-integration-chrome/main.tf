terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

# =============================================================================
# Chrome Browser Integration Module
# =============================================================================

locals {
  chrome_env = merge(
    var.allowed_domains != "" ? { MCP_CHROME_ALLOWED_DOMAINS = var.allowed_domains } : {},
    var.max_tabs != 5 ? { MCP_CHROME_MAX_TABS = tostring(var.max_tabs) } : {},
    var.session_timeout != "30m" ? { MCP_CHROME_SESSION_TIMEOUT = var.session_timeout } : {},
    var.enable_response_body ? { MCP_CHROME_ENABLE_RESPONSE_BODY = "true" } : {},
    var.env_vars,
  )
}

resource "sg_guild_integration" "chrome" {
  name        = var.integration_name
  description = var.description
  type        = "chrome"
  scope       = var.scope
  enabled     = var.enabled

  image = { name = var.integration_image }

  env = length(local.chrome_env) > 0 ? local.chrome_env : null
}
