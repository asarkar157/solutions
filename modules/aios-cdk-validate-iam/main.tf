# Customer-account read-only IAM role for CDK validate (synth lookups + cdk diff preview).
# Operator must trust Vault bastion roleArn + externalId from GET /integration/aws/config.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CdkValidateIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
      {
        Sid    = "CdkLookupReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeAvailabilityZones",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "route53:ListHostedZonesByName",
          "route53:GetHostedZone",
        ]
        Resource = "*"
      },
      {
        Sid    = "CfnReadAndChangeSetPreview"
        Effect = "Allow"
        Action = [
          "cloudformation:Describe*",
          "cloudformation:List*",
          "cloudformation:GetTemplate",
          "cloudformation:ValidateTemplate",
          "cloudformation:CreateChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:DeleteChangeSet",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyStackMutations"
        Effect = "Deny"
        Action = [
          "cloudformation:ExecuteChangeSet",
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "iam:*",
        ]
        Resource = "*"
      },
    ]
  })

  assume_statement = {
    Effect    = "Allow"
    Action    = ["sts:AssumeRole", "sts:TagSession"]
    Principal = { AWS = var.trusted_assumer_arns }
  }
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      merge(
        local.assume_statement,
        trimspace(var.external_id) != "" ? {
          Condition = { StringEquals = { "sts:ExternalId" = var.external_id } }
        } : {},
      ),
    ]
  })
}

resource "aws_iam_role" "cdk_validate" {
  name               = var.role_name
  assume_role_policy = local.assume_role_policy
}

resource "aws_iam_role_policy" "cdk_validate" {
  name   = "${var.role_name}-policy"
  role   = aws_iam_role.cdk_validate.id
  policy = local.policy_document
}
