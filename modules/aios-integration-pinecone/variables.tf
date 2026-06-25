variable "api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "pinecone_mcp_image" {
  description = "Guild Pinecone MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "pinecone-production"
}

variable "description" {
  type    = string
  default = "Pinecone vector integration"
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
