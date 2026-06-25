variable "url" {
  description = "Redis URL (`redis://` or `rediss://`)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "redis_mcp_image" {
  description = "Guild Redis MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "redis-production"
}

variable "description" {
  type    = string
  default = "Redis integration"
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
