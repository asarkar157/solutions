variable "integration_name" {
  type    = string
  default = "linear-integration"
}
variable "credential_provider_id" {
  description = "OAuth credential provider ID configured in StackGen Vault"
  type        = string
}
