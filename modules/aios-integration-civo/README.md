# aios-integration-civo

Provisions a Vault secret and Guild `civo` integration for read-only Kubernetes cluster and instance inspection via the Civo CLI.

## Vault metadata

| Key | Required | Notes |
|-----|----------|-------|
| `civo_api_key` | yes | Civo API key |

## Usage

```hcl
module "civo" {
  source = "../../modules/aios-integration-civo"

  integration_name = "prod-civo"
  civo_api_key     = var.civo_api_key
}
```

## Guild catalog

Confirm the integration type and image tag with your StackGen Guild deployment (`GET /api/v1/integrations/types`). Default image: `ghcr.io/appcd-dev/stackgen-guild-integration-civo:main`.

## Outputs

| Output | Description |
|--------|-------------|
| `integration_name` | Guild integration name for `sg_agent.integrations` |
| `secret_id` | Bound `sg_secret` ID |
