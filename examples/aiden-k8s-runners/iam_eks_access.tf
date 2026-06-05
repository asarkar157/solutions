data "aws_caller_identity" "current" {}

# SSO and assumed-role sessions return sts:assumed-role in caller identity; trust policies need the IAM role ARN.
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

locals {
  eks_access_trusted_principals = distinct(concat(
    [data.aws_iam_session_context.current.issuer_arn],
    var.eks_access_trusted_principal_arns,
  ))
}

# IAM role for kubectl / AWS CLI access via: aws eks update-kubeconfig --role-arn <this_role>
resource "aws_iam_role" "eks_cluster_access" {
  name = "${local.name_prefix}-eks-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowTrustedPrincipals"
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        AWS = local.eks_access_trusted_principals
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-access"
  })
}

# Lets the AWS CLI resolve cluster endpoint/certificate for kubeconfig generation
resource "aws_iam_role_policy" "eks_cluster_access" {
  name = "${local.name_prefix}-eks-describe"
  role = aws_iam_role.eks_cluster_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "EKSReadForKubeconfig"
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster",
        "eks:ListClusters",
      ]
      Resource = aws_eks_cluster.main.arn
    }]
  })
}

# Map the IAM role into the EKS cluster (authentication_mode API_AND_CONFIG_MAP)
resource "aws_eks_access_entry" "cluster_access" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_cluster_access.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_access" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_cluster_access.arn
  policy_arn    = var.eks_cluster_access_policy_arn

  access_scope {
    type = "cluster"
  }
}
