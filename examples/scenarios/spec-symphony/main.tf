# Scenario: spec-symphony — Stage 5 SDD factory

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

module "linear_integration" {
  count  = local.linear_integration_enabled ? 1 : 0
  source = "../../../modules/aios-integration-linear"

  integration_name       = "spec-symphony-linear"
  credential_provider_id = var.linear_credential_provider_id
  linear_api_key         = var.linear_api_key
}

locals {
  linear_integration_enabled = trimspace(var.linear_credential_provider_id) != "" || trimspace(var.linear_api_key) != ""
}

module "spec_symphony" {
  source = "../../../modules/aios-agent-spec-symphony"

  model_names = module.foundation.model_names
  policy_ids = {
    dangerous_ops     = module.policies.policy_ids.dangerous_ops
    spec_traceability = module.policies.policy_ids.spec_traceability
  }
  policy_create_flags = {
    spec_traceability = module.policies.policy_create_flags.spec_traceability
  }
  implement_engine = var.implement_engine
  cursor_api_key   = var.cursor_api_key
  github_token     = var.github_token

  sdd_framework = var.sdd_framework
  change_type   = var.change_type

  webhook_trigger_base_url = var.stackgen_url
  webhook_trigger_org_id   = var.stackgen_project_id

  existing_linear_integration_name = length(module.linear_integration) > 0 ? module.linear_integration[0].integration_name : ""

  enable_linear_product_spec_workflow = local.linear_integration_enabled && var.enable_linear_product_spec_workflow
  enable_linear_implement_workflow    = local.linear_integration_enabled && var.enable_linear_implement_workflow
  linear_implement_engine             = var.linear_implement_engine

  create_remote_runner = var.create_remote_runner
  build_runner_image   = var.build_runner_image

  power_pack_refs = var.power_pack_refs
}
