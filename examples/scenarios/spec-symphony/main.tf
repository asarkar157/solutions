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
  insecure       = var.stackgen_insecure
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

  # Advertise the runner workspace so Guild's execution-surface guard recognizes
  # Do NOT declare workspace.paths for this runner, and do NOT use timestamp()-based
  # labels here. Two reasons:
  #   1. The spec-symphony SDD factory runner is a general-purpose, ephemeral-workspace
  #      runner: each run gets a fresh WORK_ROOT (/home/runner/.wf-<run-id>, clone dir
  #      <work_root>/repo, pack under /home/runner/.spec-symphony/...). The execution-
  #      surface guard only enforces the workspace prefix when a runner declares
  #      workspace.paths; when none are declared it treats the runner as able to serve
  #      any path it is handed (terraform-provider/guild #760). Declaring explicit paths
  #      re-enables prefix enforcement and false-blocks the clone subagent spawn.
  #   2. A timestamp() value changes on every apply, which forces sg_remote_runner to
  #      re-register on every `tofu apply`, churning the runner token and briefly
  #      dropping its execute_command/execute_series tools from the agent tool registry
  #      (clone subagent then fails with "tools not available in the current tool
  #      registry"). Keep labels static/empty so the runner registers once and stays.
  remote_runner_labels = {}

  power_pack_refs = var.power_pack_refs
}
