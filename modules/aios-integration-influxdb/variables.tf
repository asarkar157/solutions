variable "instance_url" {
  type    = string
  default = ""
}

variable "token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "product_type" {
  type    = string
  default = "cloud"
}

variable "existing_secret_id" {
  type    = string
  default = ""
}

variable "influxdb_mcp_image" {
  description = "Guild InfluxDB MCP integration container image. Pin a version tag or digest — do not use :main in production."
  type        = string
}

variable "integration_name" {
  type    = string
  default = "influxdb-production"
}

variable "description" {
  type    = string
  default = "InfluxDB integration"
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
