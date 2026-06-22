output "assume_role_policy" {
  description = "IAM trust policy JSON applied to the customer role (bastion + external ID + TagSession)."
  value       = local.assume_role_policy
}

output "role_arn" {
  description = "Customer role ARN to pass as aws_role_arn in aios-integration-aws."
  value       = aws_iam_role.integration.arn
}

output "role_name" {
  description = "IAM role name in the customer account."
  value       = aws_iam_role.integration.name
}
