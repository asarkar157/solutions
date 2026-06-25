variable "dsn" {
  description = "Postgres-compatible DSN for TimescaleDB."
  type        = string
  sensitive   = true
  default     = ""
}

variable "read_only" {
  type    = string
  default = "true"
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "timescaledb_mcp_image" {
  description = "Guild TimescaleDB MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "timescaledb-production"
}

variable "description" {
  type    = string
  default = "TimescaleDB integration"
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
