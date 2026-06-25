variable "newrelic_api_key" {
  description = "New Relic user API key. Stored in Vault metadata as `newrelic_api_key`. Mutually exclusive with `existing_secret_id`."
  type        = string
  sensitive   = true
  default     = ""
}

variable "newrelic_region" {
  description = "New Relic data region (`us` or `eu`). Stored in Vault metadata as `newrelic_region`."
  type        = string
  default     = "us"
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with New Relic MCP credentials (`transport`, `url`, `newrelic_api_key`, optional `newrelic_region`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "newrelic-integration"
}

variable "description" {
  type    = string
  default = "New Relic observability integration via the official New Relic MCP endpoint."
}

variable "scope" {
  type    = string
  default = "PROJECT"
}

variable "enabled" {
  type    = bool
  default = true
}

variable "env" {
  type    = map(string)
  default = {}
}
