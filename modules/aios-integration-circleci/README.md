# aios-integration-circleci

Provisions a Vault secret and Guild `circleci` integration for pipeline failure diagnosis and CI/CD health inspection.

## Vault metadata

| Key | Required | Notes |
|-----|----------|-------|
| `circleci_token` | yes | CircleCI personal API token |

## Usage

```hcl
module "circleci" {
  source = "../../modules/aios-integration-circleci"

  integration_name = "prod-circleci"
  circleci_token   = var.circleci_token
}
```

## Guild catalog

Confirm the integration type and image tag with your StackGen Guild deployment (`GET /api/v1/integrations/types`). Default image: `ghcr.io/appcd-dev/stackgen-guild-integration-circleci:main`.

## Outputs

| Output | Description |
|--------|-------------|
| `integration_name` | Guild integration name for `sg_agent.integrations` |
| `secret_id` | Bound `sg_secret` ID |
