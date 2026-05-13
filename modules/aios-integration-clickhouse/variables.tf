variable "clickhouse_host" {
  description = "ClickHouse Cloud hostname"
  type        = string
}

variable "clickhouse_user" {
  type    = string
  default = "default"
}

variable "clickhouse_password" {
  type      = string
  sensitive = true
}

variable "clickhouse_port" {
  type    = number
  default = 8443
}

variable "clickhouse_database" {
  type    = string
  default = "default"
}

variable "clickhouse_mcp_image" {
  description = "User-provided container image running an MCP server for ClickHouse (BYOI)"
  type        = string
}

variable "integration_name" {
  type    = string
  default = "clickhouse-production"
}

variable "description" {
  type    = string
  default = "ClickHouse analytics integration for SQL queries and data pipeline health checks"
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
  description = <<-EOT
    Optional map of plain-text environment variables injected into the
    ClickHouse MCP container at launch (StackGen provider >= 0.1.17). Use for
    non-sensitive overrides such as query timeouts, proxy URLs, or feature
    toggles. Sensitive values (host credentials etc.) should go through
    `sg_secret` and be referenced via `secret_ref_ids`.
  EOT
  type        = map(string)
  default     = {}
}
