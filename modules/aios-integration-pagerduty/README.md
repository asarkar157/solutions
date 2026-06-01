# AIOS Integration — PagerDuty

Provisions a PagerDuty incident-management integration with API token stored in Vault.

## Usage

```hcl
module "pagerduty_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-pagerduty?ref=main"

  api_token = var.pagerduty_api_token
}
```

Or bind an existing vault secret:

```hcl
module "pagerduty_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-pagerduty?ref=main"

  existing_secret_id = var.pagerduty_secret_id
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID bound to the integration |
