output "iam_gate_workflow_name" {
  value = module.terraform_bot.iam_gate_workflow_name
}

output "iam_gate_webhook_id" {
  value = module.terraform_bot.iam_gate_webhook_id
}

output "iam_gate_webhook_token" {
  value     = module.terraform_bot.iam_gate_webhook_token
  sensitive = true
}

output "next_steps" {
  value = <<-EOT
    IAM gate workflow: ${module.terraform_bot.iam_gate_workflow_name}
    Webhook ID: ${module.terraform_bot.iam_gate_webhook_id}
    Configure GitHub repo webhook with the iam_gate_webhook_token (see module output).
    Open a PR that adds a new AWS SDK call — workflow posts file:line entitlement delta.
  EOT
}
