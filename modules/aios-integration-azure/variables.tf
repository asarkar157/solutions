variable "azure_subscription_id" {
  description = "Azure subscription ID for the azurerm provider"
  type        = string
  default     = ""
}

variable "azure_reader_role_scope" {
  description = "Scope for Azure reader role assignments. Defaults to subscription."
  type        = string
  default     = ""
}

variable "create_azure_reader" {
  description = "Set to true to create the Azure reader application"
  type        = bool
  default     = true
}

variable "app_display_name" {
  description = "Display name for the Azure AD application"
  type        = string
  default     = "guild-azure-reader"
}

variable "integration_name" {
  type    = string
  default = "azure-production"
}

variable "description" {
  type    = string
  default = "Azure integration for autonomous SRE operations with Azure CLI"
}

variable "scope" {
  type    = string
  default = "PROJECT"
}

variable "enabled" {
  type    = bool
  default = true
}

variable "integration_image" {
  type    = string
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-azure:main"
}
