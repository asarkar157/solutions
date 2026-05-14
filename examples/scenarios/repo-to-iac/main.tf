# =============================================================================
# Scenario: repo-to-iac
# =============================================================================
# Pre-sales pitch: "Take a legacy repo and make IaC out of it."
# Slimmed-down scenario root for SE demos. For the canonical full example
# (with optional toggles), see examples/repo-to-iac/.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

locals {
  stackgen_mcp_url = format("%s/api/mcp/user", trimsuffix(var.stackgen_url, "/"))
  stackgen_mcp_auth_header = jsonencode({
    authorization = "Bearer ${var.stackgen_token}"
  })
}

module "foundation" {
  source = "../../../modules/aios-foundation"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id

  llm_api_keys = {
    openai    = var.openai_api_key
    anthropic = var.anthropic_api_key
    gemini    = var.gemini_api_key
  }
}

module "policies" {
  source = "../../../modules/aios-policies"

  create_policies = {
    azure_tool_governance  = false
    google_tool_governance = false
    langfuse_observability = false
  }
}

module "github_integration" {
  source = "../../../modules/aios-integration-github"

  github_token = var.github_token
}

resource "sg_secret" "stackgen_mcp" {
  name        = "stackgen-mcp-credentials"
  description = "StackGen Consumer MCP — transport streamable_http; PAT in Authorization header; url /api/mcp/user."
  category    = "Other"
  subcategory = "mcp"

  metadata = {
    transport = "streamable_http"
    url       = local.stackgen_mcp_url
    headers   = local.stackgen_mcp_auth_header
  }
}

resource "sg_guild_integration" "stackgen_mcp" {
  name           = "stackgen-mcp"
  description    = "StackGen hosted MCP — Consumer endpoint for platform tools."
  type           = "mcp"
  scope          = "PROJECT"
  enabled        = true
  secret_ref_ids = [sg_secret.stackgen_mcp.id]
}

module "repo_to_iac" {
  source = "../../../modules/aios-agent-repo-to-iac"

  model_names = module.foundation.model_names

  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
  }

  existing_github_integration_name = module.github_integration.integration_name
  stackgen_mcp_integration_name    = sg_guild_integration.stackgen_mcp.name
}
