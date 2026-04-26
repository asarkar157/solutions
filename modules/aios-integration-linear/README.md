# AIOS Integration — Linear (OAuth)

Linear project management integration via OAuth. Connects directly to `mcp.linear.app` — no container image or vault secret needed.

## Usage

```hcl
module "linear_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-linear"

  credential_provider_id = var.linear_oauth_provider_id
}
```
