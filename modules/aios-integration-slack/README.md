# AIOS Integration — Slack

Provisions a Slack ChatOps integration for incident channels, approvals, and notifications.

## Usage

```hcl
module "slack_integration" {
  source = "github.com/stackgen-demo/solutions//modules/aios-integration-slack"

  slack_bot_token      = var.slack_bot_token
  slack_signing_secret = var.slack_signing_secret
  slack_webhook_url    = var.slack_webhook_url
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID |
