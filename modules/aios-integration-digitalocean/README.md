# aios-integration-digitalocean

Provisions a Vault secret and Guild `digitalocean` integration for read-only droplet, Kubernetes, and account inspection via doctl.

## Vault metadata

| Key | Required | Notes |
|-----|----------|-------|
| `digitalocean_token` | yes | DigitalOcean personal access token |

## Usage

```hcl
module "digitalocean" {
  source = "../../modules/aios-integration-digitalocean"

  integration_name    = "prod-digitalocean"
  digitalocean_token  = var.digitalocean_token
}
```

## Guild catalog

Confirm the integration type and image tag with your StackGen Guild deployment (`GET /api/v1/integrations/types`). Default image: `ghcr.io/appcd-dev/stackgen-guild-integration-digitalocean:main`.

## Outputs

| Output | Description |
|--------|-------------|
| `integration_name` | Guild integration name for `sg_agent.integrations` |
| `secret_id` | Bound `sg_secret` ID |
