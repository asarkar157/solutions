variable "uri" {
  type      = string
  sensitive = true
  default   = ""
}

variable "username" {
  type    = string
  default = "neo4j"
}

variable "password" {
  type      = string
  sensitive = true
  default   = ""
}

variable "database" {
  type    = string
  default = "neo4j"
}

variable "read_only" {
  type    = string
  default = "true"
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "neo4j_mcp_image" {
  description = "Guild Neo4j MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "neo4j-production"
}

variable "description" {
  type    = string
  default = "Neo4j graph integration"
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
