variable "es_url" {
  description = "Elasticsearch cluster URL (required unless existing_secret_id is set)."
  type        = string
  default     = ""
}

variable "es_api_key" {
  description = "Elasticsearch API key (required unless existing_secret_id is set; vault rejects empty values)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "es_ssl_skip_verify" {
  description = "Skip TLS certificate verification for HTTPS clusters."
  type        = string
  default     = "false"
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "elasticsearch_mcp_image" {
  description = "Guild Elasticsearch MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "elasticsearch-production"
}

variable "description" {
  type    = string
  default = "Elasticsearch integration"
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
