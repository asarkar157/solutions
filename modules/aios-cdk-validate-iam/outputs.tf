output "role_arn" {
  description = "Customer role ARN to pass as aws_role_arn in aios-integration-aws / cdk-bot."
  value       = aws_iam_role.cdk_validate.arn
}
