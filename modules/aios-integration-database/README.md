# AIOS Integration — Database (PostgreSQL)

Provisions a `Database`/`database` `sg_secret` and Guild `database` MCP integration (`mcp-server-postgres`) for PostgreSQL and compatible engines (including TimescaleDB when addressed via a Postgres DSN).

## Vault metadata

| Key | Required | Description |
|-----|----------|-------------|
| `driver` | yes | Driver name — use `postgres` for PostgreSQL |
| `dsn` | yes | Connection URL (`postgresql://user:pass@host:5432/db`) |
| `read_only` | no | Recommended `true` for agent read paths |

## Example

```hcl
module "postgres" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-database?ref=main"

  integration_name    = "prod-postgres"
  database_mcp_image    = var.database_mcp_image
  dsn                   = var.postgres_dsn
  read_only             = "true"
}
```

Use `existing_secret_id` when the vault secret is managed elsewhere.
