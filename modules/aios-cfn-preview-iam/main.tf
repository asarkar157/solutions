# =============================================================================
# AIOS — CloudFormation preview IAM (change-set + drift read, no execution)
# =============================================================================
# Workload-specific target role for cfn-author preview-changes and drift workflows.
# Trust principals (Vault bastion, IRSA, etc.) are passed by the root module.

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
        Sid    = "CfnChangeSetPreview"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:DescribeChangeSets",
          "cloudformation:DeleteChangeSet",
          "cloudformation:ValidateTemplate",
          "cloudformation:DescribeStacks",
          "cloudformation:ListStacks",
          "cloudformation:GetTemplate",
          "cloudformation:GetTemplateSummary",
        ]
        Resource = "*"
      },
      {
        Sid    = "CfnDriftReadOnly"
        Effect = "Allow"
        Action = [
          "cloudformation:DetectStackDrift",
          "cloudformation:DescribeStackResourceDrifts",
          "cloudformation:DescribeStackDriftDetectionStatus",
          "cloudformation:ListStackResources",
          "cloudformation:DescribeStackResources",
          "cloudformation:DescribeStackEvents",
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
          "cloudformation:ContinueUpdateRollback",
          "cloudformation:CancelUpdateStack",
        ]
        Resource = "*"
      },
    ]
  })

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
        Principal = {
          AWS = var.trusted_assumer_arns
        }
      },
    ]
  })
}

resource "aws_iam_policy" "cfn_preview" {
  name        = var.policy_name
  description = "CloudFormation change-set preview and drift read for Guild cfn-author (no stack execution)"
  policy      = local.policy_document
}

resource "aws_iam_role" "cfn_preview" {
  name               = var.role_name
  assume_role_policy = local.assume_role_policy
}

resource "aws_iam_role_policy_attachment" "cfn_preview" {
  role       = aws_iam_role.cfn_preview.name
  policy_arn = aws_iam_policy.cfn_preview.arn
}
