# AIOS Integration — Azure

Provisions an Azure service principal with Reader role, stores credentials in Vault, and creates a containerized Azure CLI MCP integration.

## Usage

```hcl
module "azure_integration" {
  source = "github.com/stackgen-demo/solutions//modules/aios-integration-azure"

  azure_subscription_id = var.azure_subscription_id
  # Optionally scope to a resource group for least privilege:
  # azure_reader_role_scope = "/subscriptions/.../resourceGroups/my-rg"
}
```

## What It Creates

| Resource | Description |
|----------|-------------|
| `azuread_application` | Azure AD app registration (or reuses existing) |
| `azuread_service_principal` | Service principal for the app |
| `azuread_application_password` | Client secret for auth |
| `azurerm_role_assignment` (×2) | Reader + Storage Account Key Operator roles |
| `sg_secret` | Vault secret storing SP credentials |
| `sg_guild_integration` | Containerized Azure CLI MCP integration |

## Outputs

| Name | Description |
|------|-------------|
| `integration_name` | Name to pass to agent modules |
| `reader_principal_id` | SP object ID for additional role assignments |
| `azure_role_scope` | Role assignment scope |
