output "role_arn" {
  description = "Pass to aios-integration-aws aws_role_arn (and Guild aws_role_arn for shared integrations)."
  value       = aws_iam_role.cfn_preview.arn
}

output "role_name" {
  description = "IAM role name for display and logging only. Wire role_arn (not this value) into additional_target_role_arns and Guild integrations."
  value       = aws_iam_role.cfn_preview.name
}

output "policy_arn" {
  description = "Managed policy ARN for the preview target role."
  value       = aws_iam_policy.cfn_preview.arn
}
