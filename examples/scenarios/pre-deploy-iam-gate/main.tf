# Scenario: pre-deploy-iam-gate — PR entitlement delta + IAM review comment.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

module "foundation" {
  source         = "../../../modules/aios-foundation"
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
}

module "github_integration" {
  source       = "../../../modules/aios-integration-github"
  github_token = var.github_token
}

module "terraform_bot" {
  source = "../../../modules/aios-agent-terraform-bot"

  model_names      = module.foundation.model_names
  policy_ids       = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  github_secret_id = module.github_integration.secret_id

  enable_cce               = true
  enable_iam_gate_workflow = true
}
