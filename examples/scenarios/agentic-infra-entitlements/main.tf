# Scenario: agentic-infra-entitlements — self-service infra with CCE entitlement guardrails.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    sg  = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

provider "aws" { region = var.aws_region }

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id
}

module "agentic_infra" {
  source = "../../agentic-infrastructure"

  stackgen_url        = var.stackgen_url
  stackgen_token      = var.stackgen_token
  stackgen_project_id = var.stackgen_project_id

  openai_api_key    = var.openai_api_key
  anthropic_api_key = var.anthropic_api_key
  gemini_api_key    = var.gemini_api_key

  aws_region                       = var.aws_region
  aws_stackgen_trust_arns          = var.aws_stackgen_trust_arns
  github_token                     = var.github_token
  enable_entitlement_guard         = true
  create_stackgen_mcp_integrations = true
}
