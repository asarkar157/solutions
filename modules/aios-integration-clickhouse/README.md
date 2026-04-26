# AIOS Integration — ClickHouse (BYOI)

Provisions a ClickHouse analytics integration using the Bring Your Own Image (BYOI) pattern.

## Usage

```hcl
module "clickhouse_integration" {
  source = "github.com/stackgen-demo/solutions//modules/aios-integration-clickhouse"

  clickhouse_host      = "abc123.us-east-1.aws.clickhouse.cloud"
  clickhouse_password  = var.clickhouse_password
  clickhouse_mcp_image = "your-registry/mcp-clickhouse:latest"
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID |
