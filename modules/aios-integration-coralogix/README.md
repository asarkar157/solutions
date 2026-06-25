# aios-integration-coralogix

Provisions a Vault secret and Guild `coralogix` integration for log queries, alerts, and observability data.

## Vault metadata

| Key | Required | Notes |
|-----|----------|-------|
| `coralogix_api_key` | yes | Coralogix API key |
| `coralogix_base_url` | yes | Coralogix API origin for your domain |

## Usage

```hcl
module "coralogix" {
  source = "../../modules/aios-integration-coralogix"

  integration_name   = "prod-coralogix"
  coralogix_api_key  = var.coralogix_api_key
  coralogix_base_url = "https://api.coralogix.com"
}
```

## Guild catalog

Confirm the integration type and image tag with your StackGen Guild deployment (`GET /api/v1/integrations/types`). Default image: `ghcr.io/appcd-dev/stackgen-guild-integration-coralogix:main`.

## Outputs

| Output | Description |
|--------|-------------|
| `integration_name` | Guild integration name for `sg_agent.integrations` |
| `secret_id` | Bound `sg_secret` ID |
