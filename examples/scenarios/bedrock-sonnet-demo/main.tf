# =============================================================================
# Scenario: bedrock-sonnet-demo
# =============================================================================
# Demonstrates Claude Sonnet 4.6 on Amazon Bedrock (no direct Anthropic API key).
# Wires foundation-bedrock + policies + AWS integration + AWS-SRE agent.
# See ./README.md for prerequisites and demo steps.

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

module "aws_integration" {
  source = "../../../modules/aios-integration-aws"

  aws_role_arn = var.aws_role_arn
  aws_region   = var.aws_region
}

module "aws_sre" {
  source = "../../../modules/aios-agent-aws-sre"

  model_names                   = module.foundation_bedrock.model_names
  policy_ids                    = { dangerous_ops = module.policies.policy_ids.dangerous_ops }
  existing_aws_integration_name = module.aws_integration.integration_name
}

output "bedrock_model_names" {
  description = "Guild model names wired to the AWS SRE agent (Bedrock Claude Sonnet 4.6)."
  value       = module.foundation_bedrock.model_names
}

output "bedrock_inference_profile_id" {
  description = "Bedrock model_id (inference profile) used for Sonnet 4.6."
  value       = module.foundation_bedrock.inference_profile_id
}
