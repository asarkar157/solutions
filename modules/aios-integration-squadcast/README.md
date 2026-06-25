# aios-integration-squadcast

Provisions a Vault secret and Guild `squadcast` integration for incidents, on-call schedules, and escalation policies.

## Vault metadata

| Key | Required | Notes |
|-----|----------|-------|
| `squadcast_refresh_token` | yes | SquadCast OAuth refresh token |
| `squadcast_region` | yes | `us` or `eu` |

## Usage

```hcl
module "squadcast" {
  source = "../../modules/aios-integration-squadcast"

  integration_name        = "prod-squadcast"
  squadcast_refresh_token = var.squadcast_refresh_token
  squadcast_region        = "us"
}
```

## Guild catalog

Confirm the integration type and image tag with your StackGen Guild deployment (`GET /api/v1/integrations/types`). Default image: `ghcr.io/appcd-dev/stackgen-guild-integration-squadcast:main`.

## Outputs

| Output | Description |
|--------|-------------|
| `integration_name` | Guild integration name for `sg_agent.integrations` |
| `secret_id` | Bound `sg_secret` ID |
