# =============================================================================
# Scenario: monorepo-services-split
# =============================================================================
# Pre-sales pitch: "We have a monolith codebase — can you tell us how to split it?"

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.23, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
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

module "ubuntu_integration" {
  source = "../../../modules/aios-integration-ubuntu"

  integration_name = "monorepo-split-demo-ubuntu"
  secret_ref_ids   = [module.github_integration.secret_id]
  install_tools    = ["gh", "git", "curl", "jq"]
}

module "monorepo_services_splitter" {
  source = "../../../modules/aios-agent-monorepo-services-splitter"

  model_names = module.foundation.model_names

  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
  }

  github_secret_id = module.github_integration.secret_id

  integration_names = {
    github     = module.github_integration.integration_name
    ubuntu_cli = module.ubuntu_integration.integration_name
  }

  enable_cursor_integration            = var.enable_cursor_integration
  existing_cursor_mcp_integration_name = var.cursor_mcp_integration_name

  enable_github_webhook = var.enable_github_webhook
  default_branch        = var.default_branch
}
