terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.5, < 0.2.0"
    }
  }
}

# =============================================================================
# AWS Integration Module
# =============================================================================
# Creates a Vault secret with AWS role ARN and a containerized MCP integration
# for the AWS CLI. Credentials are resolved JIT from Vault at container launch.

resource "sg_secret" "aws_vault" {
  name        = "${var.integration_name}-vault"
  description = "AWS Role Assumption credentials for ${var.integration_name}"
  category    = "CloudProvider"
  subcategory = "aws"
  metadata = {
    aws_role_arn = var.aws_role_arn
    aws_region   = var.aws_region
  }
}

resource "sg_guild_integration" "aws" {
  name           = var.integration_name
  description    = var.description
  type           = "aws"
  scope          = var.scope
  secret_ref_ids = [sg_secret.aws_vault.id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }
}
