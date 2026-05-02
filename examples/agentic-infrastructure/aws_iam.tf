# -----------------------------------------------------------------------------
# AWS IAM role for aios-integration-aws (Vault assume-role)
# -----------------------------------------------------------------------------
# Replaces a hand-pasted aws_role_arn: this root creates the role and passes
# its ARN into module.aws_integration. Apply requires AWS credentials for your
# account (provider "aws"), separate from StackGen (provider "sg").

data "aws_iam_policy_document" "stackgen_trust" {
  # Only built when using trust ARNs (no full JSON). Omitting principals breaks IAM.
  count = (
    var.aws_integration_assume_role_policy_json == null
    && length(var.aws_stackgen_trust_arns) > 0
  ) ? 1 : 0

  statement {
    sid     = "StackGenAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.aws_stackgen_trust_arns
    }
  }
}

locals {
  aws_integration_assume_role_policy = (
    var.aws_integration_assume_role_policy_json != null
    ? var.aws_integration_assume_role_policy_json
    : data.aws_iam_policy_document.stackgen_trust[0].json
  )
}

resource "aws_iam_role" "stackgen_aws_integration" {
  name               = var.aws_integration_role_name
  assume_role_policy = local.aws_integration_assume_role_policy

  tags = var.aws_integration_role_tags
}

resource "aws_iam_role_policy_attachment" "stackgen_aws_integration" {
  for_each = toset(var.aws_integration_managed_policy_arns)

  role       = aws_iam_role.stackgen_aws_integration.name
  policy_arn = each.value
}
