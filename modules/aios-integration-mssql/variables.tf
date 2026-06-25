variable "mssql_host" {
  type    = string
  default = ""
}

variable "mssql_port" {
  type    = number
  default = 1433
}

variable "mssql_database" {
  type    = string
  default = ""
}

variable "mssql_user" {
  type    = string
  default = ""
}

variable "mssql_password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "existing_secret_id" {
  description = "Optional pre-existing sg_secret ID."
  type        = string
  default     = ""
}

variable "mssql_mcp_image" {
  description = "Guild Microsoft SQL Server MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "mssql-production"
}

variable "description" {
  type    = string
  default = "Microsoft SQL Server integration"
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
