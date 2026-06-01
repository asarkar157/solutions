# AIOS Integration — Palo Alto Networks (PAN-OS)

Provisions a Palo Alto Networks firewall Guild integration with PAN-OS management URL and API credentials stored in Vault.

## Vault metadata

| Key | Required | Description |
|-----|----------|-------------|
| `management_url` | yes | PAN-OS management endpoint (HTTPS) |
| `api_key` | preferred | XML API key for read-only log and policy queries |
| `username` | optional | Basic auth username when API key alone is insufficient |
| `password` | optional | Basic auth password paired with `username` |

Vault **subcategory**: `paloalto` (category `Security`).

## Integration type

Default `integration_type` is `paloalto` with image `ghcr.io/appcd-dev/stackgen-guild-integration-paloalto:main`. **Confirm the `type` string against your Guild integration catalog** (`builtins.json` / deployment catalog) before production apply — custom deployments may register a different type label.

## Usage

```hcl
module "paloalto_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-paloalto?ref=main"

  management_url = "https://fw-mgmt.internal.example.com"
  api_key      = var.paloalto_api_key
}
```

Or bind an existing vault secret:

```hcl
module "paloalto_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-paloalto?ref=main"

  existing_secret_id = var.paloalto_secret_id
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID bound to the integration |
