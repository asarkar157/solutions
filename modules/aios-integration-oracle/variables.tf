variable "connection_string" {
  type      = string
  sensitive = true
  default   = ""
}

variable "username" {
  type    = string
  default = ""
}

variable "password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "wallet" {
  type      = string
  sensitive = true
  default   = ""
}

variable "use_oci" {
  type    = string
  default = "false"
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "oracle_mcp_image" {
  description = "Guild Oracle Database MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "oracle-production"
}

variable "description" {
  type    = string
  default = "Oracle Database integration"
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
