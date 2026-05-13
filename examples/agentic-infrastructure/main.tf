# =============================================================================
# Agentic infrastructure (platform guardrails + app-team natural language)
# =============================================================================
# Provisions StackGen agents and workflows so application teams can describe
# greenfield or brownfield infrastructure in plain language. Governance is
# enforced by shared Rego policies and agent policy attachments configured here.
#
# For IDE-based natural language against the StackGen platform MCP,
# see README.md and cursor-mcp.stackgen.example.json.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id
  # Default true: Guild may adopt existing objects on some Create 409/500 responses.
  # adopt_on_conflict = false
}

locals {
  # Hosted MCP URLs per StackGen MCP docs: /api/mcp/user (Consumer) and /api/mcp/admin (Producer).
  # Vault MCP metadata uses transport streamable_http (MCPSecretResolver).
  stackgen_mcp_url = format("%s/api/mcp/user", trimsuffix(var.stackgen_url, "/"))
  stackgen_mcp_auth_header = jsonencode({
    authorization = "Bearer ${var.stackgen_token}"
  })
}

# -----------------------------------------------------------------------------
# Layer 0 — Models / secrets and org-wide policies
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# Layer 1 — AWS tool plane for the cloud infrastructure engineer agent
# -----------------------------------------------------------------------------

module "aws_integration" {
  source = "../../modules/aios-integration-aws"

  aws_role_arn = aws_iam_role.stackgen_aws_integration.arn
  aws_region   = var.aws_region
}

# -----------------------------------------------------------------------------
# Layer 1 — StackGen platform MCP (single Guild integration)
# -----------------------------------------------------------------------------
# One MCP integration pointing at the Consumer hosted URL (see StackGen MCP docs).
# Vault Other/mcp: transport, url, headers — MCPSecretResolver.

resource "sg_secret" "stackgen_mcp" {
  count = var.create_stackgen_mcp_integrations ? 1 : 0

  name        = var.stackgen_mcp_secret_name
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
  count = var.create_stackgen_mcp_integrations ? 1 : 0

  name        = var.stackgen_mcp_integration_name
  description = "StackGen hosted MCP — Consumer endpoint for platform tools."
  type        = "mcp"
  scope       = "PROJECT"
  enabled     = true

  secret_ref_ids = [sg_secret.stackgen_mcp[0].id]
}

# -----------------------------------------------------------------------------
# Layer 1 — GitHub SCM + repository → IaC (same MCP + PAT pattern as repo-to-iac example)
# -----------------------------------------------------------------------------
# When github_token is set, registers the GitHub Guild integration and
# aios-agent-repo-to-iac (repository-to-iac + repo-scan-appstack-github-export).
# Reuses the StackGen Consumer MCP integration above — no duplicate sg_secret.

locals {
  github_integration_enabled = trimspace(var.github_token) != ""
}

module "github_integration" {
  count  = local.github_integration_enabled ? 1 : 0
  source = "../../modules/aios-integration-github"

  github_token = var.github_token
}

module "repo_to_iac" {
  count  = local.github_integration_enabled ? 1 : 0
  source = "../../modules/aios-agent-repo-to-iac"

  model_names = {
    gpt4o         = module.foundation.model_names.gpt4o
    claude_sonnet = module.foundation.model_names.claude_sonnet
  }

  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
  }

  github_integration_name = module.github_integration[0].integration_name

  stackgen_mcp_integration_name = var.create_stackgen_mcp_integrations ? var.stackgen_mcp_integration_name : ""
}

# -----------------------------------------------------------------------------
# Layer 2 — Minimal SRE surface (runbooks + risk agent referenced by SDLC graph)
# -----------------------------------------------------------------------------

module "sre_agents" {
  source = "../../modules/aios-agent-sre"

  # Optional: set policy_create_flags = module.policies.policy_create_flags when module.policies.create_policies turns policies off, so attachment counts match (see aios-agent-sre README). Omitted here because defaults match the policies module default (all policies on).

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops            = module.policies.policy_ids.dangerous_ops
    sre_remediation          = module.policies.policy_ids.sre_remediation
    prod_write_gate          = module.policies.policy_ids.prod_write_gate
    tier0_service_protection = module.policies.policy_ids.tier0_service_protection
    blast_radius_limit       = module.policies.policy_ids.blast_radius_limit
    freeze_window            = module.policies.policy_ids.freeze_window
    data_risk_pii            = module.policies.policy_ids.data_risk_pii
    post_action_verification = module.policies.policy_ids.post_action_verification
  }

  integration_names = {}
}

# -----------------------------------------------------------------------------
# Layer 2 — SDLC: developer request intake + cloud infrastructure engineer
# -----------------------------------------------------------------------------

module "sdlc" {
  source = "../../modules/aios-agent-sdlc"

  model_names = {
    gpt4o         = module.foundation.model_names.gpt4o
    claude_sonnet = module.foundation.model_names.claude_sonnet
  }

  policy_ids = {
    dangerous_ops = module.policies.policy_ids.dangerous_ops
  }

  sre_agent_names = {
    sre_risk_posture = module.sre_agents.agent_names.sre_risk_posture
  }

  sre_runbook_names = {
    deployment_rollback = "argocd-rollback"
    ssl_cert_renewal    = "tls-certificate-renewal"
  }

  sre_evidence_checklist_names = {
    change_validation = module.sre_agents.evidence_checklist_names.change_validation
  }

  integration_names = merge(
    {
      aws_production = module.aws_integration.integration_name
    },
    var.create_stackgen_mcp_integrations ? { stackgen_mcp = var.stackgen_mcp_integration_name } : {},
    local.github_integration_enabled ? { github_scm = module.github_integration[0].integration_name } : {},
    trimspace(var.gcp_integration_name) != "" ? { gcp_production = var.gcp_integration_name } : {},
    trimspace(var.slack_integration_name) != "" ? { slack = var.slack_integration_name } : {},
  )

  linear_mcp_integration_name = var.linear_integration_name

  github_token = var.github_token
}
