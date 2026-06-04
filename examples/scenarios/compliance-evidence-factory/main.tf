# Scenario: compliance-evidence-factory — quarterly multi-repo CCE audit evidence.

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

module "compliance_auditor" {
  source = "../../../modules/aios-agent-compliance-auditor"

  model_names = module.foundation.model_names
  policy_ids  = { dangerous_ops = module.policies.policy_ids.dangerous_ops }

  github_secret_id = module.github_integration.secret_id

  enable_cce                         = true
  enable_compliance_evidence_factory = true
  audit_repo_list                    = var.audit_repo_list
}

module "compliance_schedules" {
  source = "../../../modules/aios-agent-schedules"

  target_type = "workflow"
  target_name = module.compliance_auditor.compliance_evidence_factory_workflow_name

  schedules = [{
    name       = "quarterly-compliance-evidence"
    expression = "0 9 1 */3 *"
    action     = "Run quarterly compliance evidence scan across all audit_repo_list repositories."
  }]
}
