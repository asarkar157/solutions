# aios-integration-newrelic

Provisions a New Relic observability integration using the official New Relic remote MCP server credentials stored in Vault (no sidecar image).

## Vault metadata

| Key | Required | Notes |
|-----|----------|-------|
| `transport` | yes | `streamable_http` |
| `url` | yes | `https://mcp.newrelic.com/mcp/` |
| `newrelic_api_key` | yes | New Relic user API key |
| `newrelic_region` | no | `us` (default) or `eu` |

## Usage

```hcl
module "newrelic" {
  source = "../../modules/aios-integration-newrelic"

  integration_name  = "prod-newrelic"
  newrelic_api_key  = var.newrelic_api_key
  newrelic_region   = "us"
}
```

Or bind an existing vault secret:

```hcl
module "newrelic" {
  source = "../../modules/aios-integration-newrelic"

  existing_secret_id = var.newrelic_secret_id
}
```

## Outputs

| Output | Description |
|--------|-------------|
| `integration_name` | Guild integration name for `sg_agent.integrations` |
| `secret_id` | Bound `sg_secret` ID |
