# =============================================================================
# Repository → IaC — GitHub URL + StackGen MCP
# =============================================================================
# Registers the repository-to-iac workflow: analyze a GitHub repo and generate
# IaC using StackGen MCP tools. Requires GitHub PAT integration; optionally
# registers one StackGen MCP guild integration (Vault Other/mcp).

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.8, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id
  # adopt_on_conflict = false
}

locals {
  stackgen_mcp_url = format("%s/api/mcp/user", trimsuffix(var.stackgen_url, "/"))
  stackgen_mcp_auth_header = jsonencode({
    authorization = "Bearer ${var.stackgen_token}"
  })
}

module "foundation" {
  source = "../../modules/aios-foundation"

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
  source = "../../modules/aios-policies"
}

module "github_integration" {
  source = "../../modules/aios-integration-github"

  github_token = var.github_token
}

resource "sg_secret" "stackgen_mcp" {
  count = var.create_stackgen_mcp_integrations ? 1 : 0

  name        = var.stackgen_mcp_secret_name
  description = "StackGen MCP SSE + PAT (repository-to-iac agent)."
  category    = "Other"
  subcategory = "mcp"

  metadata = {
    transport = "streamable_http"
    url       = local.stackgen_mcp_url
    headers   = local.stackgen_mcp_auth_header
  }
}

resource "sg_guild_integration" "stackgen_mcp" {
  count = var.create_stackgen_mcp_integrations ? 1 : 0

  name           = var.stackgen_mcp_integration_name
  description    = "StackGen MCP for repo-to-iac workflow."
  type           = "mcp"
  scope          = "PROJECT"
  enabled        = true
  secret_ref_ids = [sg_secret.stackgen_mcp[0].id]
}

module "repo_to_iac" {
  source = "../../modules/aios-agent-repo-to-iac"

  model_names = {
    gpt4o         = module.foundation.model_names.gpt4o
    claude_sonnet = module.foundation.model_names.claude_sonnet
  }

  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
  }

  github_integration_name = module.github_integration.integration_name

  stackgen_mcp_integration_name = var.create_stackgen_mcp_integrations ? var.stackgen_mcp_integration_name : ""
}
