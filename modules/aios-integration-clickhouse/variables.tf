variable "clickhouse_host" {
  description = "ClickHouse Cloud hostname (required unless `existing_secret_id` is set)."
  type        = string
  default     = ""
}

variable "clickhouse_user" {
  type    = string
  default = "default"
}

variable "clickhouse_password" {
  description = "ClickHouse password (required unless `existing_secret_id` is set)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = <<-EOT
    Optional pre-existing `sg_secret` ID to bind to this integration. When set,
    this module SKIPS provisioning the `sg_secret` and only creates the
    `sg_guild_integration`. The supplied secret must already be `CloudProvider`/
    `clickhouse` shape with the standard CLICKHOUSE_* metadata keys.
  EOT
  type        = string
  default     = ""
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
