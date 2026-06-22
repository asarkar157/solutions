# Customer-account IAM role for StackGen AWS MCP integrations (SRE read-only by default).
# Trust policy matches Vault / Guild AWS integration Step 1: bastion principal,
# workspace external ID on AssumeRole, and a separate TagSession statement.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.bastion_role_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = var.bastion_role_arn
        }
        Action = "sts:TagSession"
      },
    ]
  })
}

resource "aws_iam_role" "integration" {
  name               = var.role_name
  assume_role_policy = local.assume_role_policy
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.integration.name
  policy_arn = each.value
}
