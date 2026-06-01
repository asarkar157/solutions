# AIOS Integration — ServiceNow

Provisions a ServiceNow ITSM Guild integration with instance URL and basic-auth credentials stored in Vault.

## Usage

```hcl
module "servicenow_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-servicenow?ref=main"

  instance_url = "https://your-org.service-now.com"
  username     = var.servicenow_username
  password     = var.servicenow_password
}
```

Or bind an existing vault secret (metadata keys: `base_url`, `username`, `password`):

```hcl
module "servicenow_integration" {
  source = "github.com/appcd-dev/solutions//modules/aios-integration-servicenow?ref=main"

  existing_secret_id = var.servicenow_secret_id
}
```

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `secret_id` | Vault secret ID bound to the integration |
