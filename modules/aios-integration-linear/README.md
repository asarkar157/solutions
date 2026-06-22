# AIOS Integration — Linear (OAuth or API key)

Linear project management via remote MCP (`mcp.linear.app`).

## Auth modes (pick one)

**OAuth** — StackGen Vault credential provider (per-user tokens):

```hcl
module "linear_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-linear"

  credential_provider_id = var.linear_oauth_provider_id
}
```

**Personal API key** — vault secret with `LINEAR_API_KEY`:

```hcl
module "linear_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-linear"

  linear_api_key = var.linear_api_key
}
```
