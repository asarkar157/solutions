# AIOS Integration — Grafana

Provisions a Grafana observability integration with API token stored in Vault.

## Usage

```hcl
module "grafana_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-grafana"

  grafana_server = "https://grafana.example.com"
  grafana_token  = var.grafana_api_token
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID |
