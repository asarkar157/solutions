variable "integration_name" {
  type    = string
  default = "linear-integration"
}

variable "description" {
  type    = string
  default = ""
}

variable "scope" {
  type    = string
  default = "PROJECT"
}

variable "enabled" {
  type    = bool
  default = true
}

variable "credential_provider_id" {
  description = "OAuth credential provider ID configured in StackGen Vault (mutually exclusive with linear_api_key)."
  type        = string
  default     = ""
}

variable "linear_api_key" {
  description = "Linear personal API key (lin_api_…). Creates vault secret when set (mutually exclusive with credential_provider_id)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Existing sg_secret ID with LINEAR_API_KEY metadata instead of inline linear_api_key."
  type        = string
  default     = ""
}
