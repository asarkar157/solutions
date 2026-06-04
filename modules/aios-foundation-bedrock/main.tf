# =============================================================================
# AIOS Foundation — Amazon Bedrock (Claude Sonnet 4.6)
# =============================================================================
# Registers a Bedrock model provider and Claude Sonnet 4.6 via cross-region
# inference profile. Compose alongside aios-foundation (direct API keys) or use
# alone when all agent LLM traffic should stay on AWS Bedrock.
#
# The root module must configure the "sg" provider (stackgen_url / stackgen_token).

locals {
  bedrock_region_prefix = {
    "us-east-1"      = "us"
    "us-east-2"      = "us"
    "us-west-1"      = "us"
    "us-west-2"      = "us"
    "eu-west-1"      = "eu"
    "eu-west-2"      = "eu"
    "eu-west-3"      = "eu"
    "eu-central-1"   = "eu"
    "eu-north-1"     = "eu"
    "ap-south-1"     = "apac"
    "ap-southeast-1" = "apac"
    "ap-southeast-2" = "apac"
    "ap-northeast-1" = "apac"
    "ap-northeast-2" = "apac"
    "ap-northeast-3" = "apac"
  }

  bedrock_prefix = lookup(local.bedrock_region_prefix, var.aws_region, "us")

  claude_sonnet_46_model_id = trimspace(var.inference_profile_id) != "" ? trimspace(var.inference_profile_id) : "${local.bedrock_prefix}.anthropic.claude-sonnet-4-6"

  bedrock_use_iam = try(var.bedrock_auth.use_iam_role, false)

  bedrock_static_keys = trimspace(try(var.bedrock_auth.aws_access_key_id, "")) != "" && trimspace(try(var.bedrock_auth.aws_secret_access_key, "")) != ""

  bedrock_enabled = local.bedrock_use_iam || local.bedrock_static_keys
}

# =============================================================================
# Bedrock AWS credentials (optional — omit when Guild uses IAM role auth)
# =============================================================================

resource "sg_secret" "bedrock" {
  count       = local.bedrock_static_keys ? 1 : 0
  name        = "${var.name_prefix}bedrock-aws-creds"
  description = "AWS credentials for Amazon Bedrock (Claude Sonnet 4.6)"
  category    = "LLM"
  subcategory = "bedrock"
  metadata = {
    AWS_ACCESS_KEY_ID     = var.bedrock_auth.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.bedrock_auth.aws_secret_access_key
    AWS_SESSION_TOKEN     = try(var.bedrock_auth.aws_session_token, "")
    AWS_REGION            = var.aws_region
  }
}

# =============================================================================
# Model provider + Claude Sonnet 4.6 on Bedrock
# =============================================================================

resource "sg_guild_model_provider" "bedrock" {
  count           = local.bedrock_enabled ? 1 : 0
  name            = var.provider_name
  provider_type   = "bedrock"
  host            = var.aws_region
  token_reference = local.bedrock_static_keys ? sg_secret.bedrock[0].name : null
}

resource "sg_guild_model" "claude_sonnet_bedrock" {
  count         = local.bedrock_enabled ? 1 : 0
  name          = var.model_name
  provider_name = sg_guild_model_provider.bedrock[0].name
  model_id      = local.claude_sonnet_46_model_id
  good_for_task = var.good_for_task
}

check "bedrock_auth_configured" {
  assert {
    condition     = local.bedrock_enabled
    error_message = "Configure bedrock_auth: set use_iam_role = true (Guild on AWS with Bedrock IAM) or supply aws_access_key_id and aws_secret_access_key."
  }
}
