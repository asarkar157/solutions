variable "mysql_host" {
  description = "MySQL hostname (required unless `existing_secret_id` is set)."
  type        = string
  default     = ""
}

variable "mysql_port" {
  type    = number
  default = 3306
}

variable "mysql_database" {
  type    = string
  default = ""
}

variable "mysql_user" {
  type    = string
  default = ""
}

variable "mysql_password" {
  description = "MySQL password (required unless `existing_secret_id` is set)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional pre-existing `sg_secret` ID (`Database`/`mysql` metadata keys)."
  type        = string
  default     = ""
}

variable "mysql_mcp_image" {
  description = "Guild MySQL MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "mysql-production"
}

variable "description" {
  type    = string
  default = "MySQL integration for SQL queries via MCP Toolbox"
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
