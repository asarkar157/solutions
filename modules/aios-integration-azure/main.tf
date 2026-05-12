terraform {
  required_version = ">= 1.5"
  required_providers {
    sg      = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.10, < 0.2.0" }
    azuread = { source = "hashicorp/azuread", version = "~> 2.47" }
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.85" }
  }
}

# =============================================================================
# Azure Integration Module
# =============================================================================
# Creates an Azure AD service principal with Reader role, stores credentials
# in Vault, and provisions a containerized Azure CLI MCP integration.

data "azurerm_subscription" "current" {}
data "azuread_client_config" "current" {}

data "azuread_application" "existing_reader" {
  count        = var.create_azure_reader ? 0 : 1
  display_name = var.app_display_name
}

locals {
  azure_role_scope       = var.azure_reader_role_scope != "" ? var.azure_reader_role_scope : data.azurerm_subscription.current.id
  azure_reader_app_id    = var.create_azure_reader ? azuread_application.guild_azure_reader[0].id : data.azuread_application.existing_reader[0].id
  azure_reader_client_id = var.create_azure_reader ? azuread_application.guild_azure_reader[0].client_id : data.azuread_application.existing_reader[0].client_id
}

resource "azuread_application" "guild_azure_reader" {
  count        = var.create_azure_reader ? 1 : 0
  display_name = var.app_display_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "guild_azure_reader" {
  client_id    = local.azure_reader_client_id
  use_existing = true
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "guild_azure_reader" {
  application_id = local.azure_reader_app_id
  display_name   = "guild-sre-readonly"
}

resource "azurerm_role_assignment" "guild_reader" {
  scope                = local.azure_role_scope
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.guild_azure_reader.object_id
}

resource "azurerm_role_assignment" "guild_storage_key_operator" {
  scope                = local.azure_role_scope
  role_definition_name = "Storage Account Key Operator Service Role"
  principal_id         = azuread_service_principal.guild_azure_reader.object_id
}

resource "sg_secret" "azure_vault" {
  name        = "${var.integration_name}-vault"
  description = "Azure service principal credentials (Reader role)"
  category    = "CloudProvider"
  subcategory = "azure"
  metadata = {
    client_id       = local.azure_reader_client_id
    tenant_id       = data.azuread_client_config.current.tenant_id
    client_secret   = azuread_application_password.guild_azure_reader.value
    subscription_id = data.azurerm_subscription.current.subscription_id
  }
}

resource "sg_guild_integration" "azure" {
  name           = var.integration_name
  description    = var.description
  type           = "azure"
  scope          = var.scope
  secret_ref_ids = [sg_secret.azure_vault.id]
  enabled        = var.enabled

  image = {
    name = var.integration_image
  }
}
