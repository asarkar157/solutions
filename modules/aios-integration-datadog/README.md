# AIOS Integration — Datadog

Provisions a Datadog observability integration using the official Datadog MCP server credentials stored in Vault.

## Usage

```hcl
module "datadog_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-datadog?ref=main"

  datadog_api_key = var.datadog_api_key
  datadog_app_key = var.datadog_app_key
  datadog_site    = "datadoghq.com"
}
```

Or bind an existing vault secret:

```hcl
module "datadog_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-datadog?ref=main"

  existing_secret_id = var.datadog_secret_id
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID bound to the integration |
