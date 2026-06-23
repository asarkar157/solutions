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

### Optional: sync Datadog playbooks into Guild runbooks

After SRE discovery lists notebooks/workflows, enable per-integration sync via `env` (see [stackgen-sre-app `docs/runbook-sync.md`](https://github.com/appcd-dev/guild-apps/stackgen-sre-app/blob/main/docs/runbook-sync.md)):

```hcl
module "datadog_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-datadog?ref=main"

  datadog_api_key = var.datadog_api_key
  datadog_app_key = var.datadog_app_key

  runbook_sync_enabled      = true
  runbook_sync_notebook_ids = "12345,67890"
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID bound to the integration |
