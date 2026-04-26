variable "cursor_api_key" {
  type      = string
  sensitive = true
}
variable "integration_name" {
  type    = string
  default = "cursor-tool"
}
variable "integration_image" {
  type    = string
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-cursor:main"
}
variable "name_prefix" {
  type    = string
  default = ""
}
