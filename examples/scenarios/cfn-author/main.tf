# Scenario: cfn-author — Intent to Infrastructure + Drift Management (Bedrock Sonnet 4.6)

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

provider "aws" {
  region = var.aws_region
}

locals {
  cfn_preview_role_arn = var.create_cfn_preview_iam_role ? module.cfn_preview_iam[0].role_arn : trimspace(var.aws_role_arn)
}

module "cfn_preview_iam" {
  count  = var.create_cfn_preview_iam_role ? 1 : 0
  source = "../../../modules/aios-cfn-preview-iam"

  role_name            = var.cfn_preview_role_name
  trusted_assumer_arns = var.trusted_assumer_arns
}

module "foundation_bedrock" {
  source = "../../../modules/aios-foundation-bedrock"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id
  aws_region     = var.aws_region

  bedrock_auth = var.bedrock_use_iam_role ? {
    use_iam_role = true
    } : {
    aws_access_key_id     = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
    aws_session_token     = var.aws_session_token
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

module "aws_integration" {
  source = "../../../modules/aios-integration-aws"

  aws_role_arn = local.cfn_preview_role_arn
  aws_region   = var.aws_region
}

module "cfn_author" {
  source = "../../../modules/aios-agent-cfn-author"

  model_names = module.foundation_bedrock.model_names

  policy_ids = {
    dangerous_ops   = module.policies.policy_ids.dangerous_ops
    prod_write_gate = module.policies.policy_ids.prod_write_gate
  }

  target_repository_full_name = var.target_repository_full_name
  cfn_template_catalog_path   = "cloudformation/catalog/"
  default_aws_regions         = [var.aws_region]

  existing_github_integration_name = module.github_integration.integration_name
  existing_aws_integration_name    = module.aws_integration.integration_name

  enable_drift_schedule = var.enable_drift_schedule
  drift_schedule_cron   = "0 6 * * *"

  enable_intent_webhook     = true
  enable_compliance_webhook = true
  enable_drift_webhook      = var.enable_drift_webhook
  webhook_trigger_base_url  = var.stackgen_url
  webhook_trigger_org_id    = var.stackgen_project_id

  workspace = {
    workspace_id         = var.target_repository_full_name
    source_type          = "git"
    primary_iac          = "cloudformation"
    self_healing_allowed = false
  }
}

output "bedrock_model_names" {
  value = module.foundation_bedrock.model_names
}

output "cfn_preview_role_arn" {
  description = "AWS integration target role — add to Vault bastion additional_target_role_arns when using local Vault."
  value       = local.cfn_preview_role_arn
}

output "workflow_names" {
  value = module.cfn_author.workflow_names
}

output "recommended_skill_names" {
  value = module.cfn_author.recommended_skill_names
}

output "drift_schedule_names" {
  value = module.cfn_author.drift_schedule_names
}

output "intent_webhook_ingress_payload_url" {
  description = "POST this URL with JSON intent to trigger intent-to-infrastructure remotely."
  value       = module.cfn_author.intent_webhook_ingress_payload_url
  sensitive   = true
}

output "compliance_webhook_ingress_payload_url" {
  description = "POST this URL for FedRAMP/baseline preflight (cfn-contextual-compliance)."
  value       = module.cfn_author.compliance_webhook_ingress_payload_url
  sensitive   = true
}

output "drift_webhook_ingress_payload_url" {
  description = "POST drifted_stacks JSON when enable_drift_webhook is true."
  value       = module.cfn_author.drift_webhook_ingress_payload_url
  sensitive   = true
}
