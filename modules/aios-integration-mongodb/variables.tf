variable "connection_string" {
  description = "MongoDB URI (`mongodb://` or `mongodb+srv://`)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "mongodb_mcp_image" {
  description = "Guild MongoDB MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "mongodb-production"
}

variable "description" {
  type    = string
  default = "MongoDB read-only integration"
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
