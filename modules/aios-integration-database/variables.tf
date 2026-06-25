variable "dsn" {
  description = "PostgreSQL connection URL (postgres:// or postgresql://)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "driver" {
  description = "Database driver name for vault (e.g. postgres)."
  type        = string
  default     = "postgres"
}

variable "read_only" {
  type    = string
  default = "true"
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "database_mcp_image" {
  description = "Guild PostgreSQL MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "postgres-production"
}

variable "description" {
  type    = string
  default = "PostgreSQL integration"
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
