# aios-integration-firehydrant

Provisions a Vault secret and Guild `firehydrant` integration for incident timelines, responders, and linked alerts.

## Vault metadata

| Key | Required | Notes |
|-----|----------|-------|
| `api_token` | yes | FireHydrant API key (`fhb-...`) |
| `base_url` | no | API origin; defaults to `https://api.firehydrant.io` |

## Usage

```hcl
module "firehydrant" {
  source = "../../modules/aios-integration-firehydrant"

  integration_name = "privatesaas-firehydrant"
  api_key          = var.firehydrant_api_key
  # base_url       = "https://api.firehydrant.io"
}
```

## Guild catalog

Confirm the integration type and image tag with your StackGen Guild deployment (`GET /api/v1/integrations/types`). Default image: `ghcr.io/appcd-dev/stackgen-guild-integration-firehydrant:main`.

## Outputs

| Output | Description |
|--------|-------------|
| `integration_name` | Guild integration name for `sg_agent.integrations` |
| `secret_id` | Bound `sg_secret` ID |
