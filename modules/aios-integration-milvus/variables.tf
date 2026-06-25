variable "uri" {
  type    = string
  default = ""
}

variable "token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "milvus_mcp_image" {
  description = "Guild Milvus MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "milvus-production"
}

variable "description" {
  type    = string
  default = "Milvus vector integration"
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
