variable "datadog_api_key" {
  description = "Datadog API key. Used when creating a new vault secret. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_app_key" {
  description = "Datadog application key paired with `datadog_api_key`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_site" {
  description = "Datadog site hostname (e.g. datadoghq.com, datadoghq.eu, us3.datadoghq.com)."
  type        = string
  default     = "datadoghq.com"
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with Datadog MCP credentials. Mutually exclusive with `datadog_api_key`."
  type        = string
  default     = ""
}

variable "integration_name" {
  description = "Guild integration resource name."
  type        = string
  default     = "datadog-integration"
}

variable "description" {
  type    = string
  default = "Datadog observability integration (official Datadog MCP server)."
}

variable "scope" {
  type    = string
  default = "PROJECT"
}

variable "enabled" {
  type    = bool
  default = true
}
