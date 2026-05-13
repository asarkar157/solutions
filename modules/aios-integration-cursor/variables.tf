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

variable "env" {
  description = <<-EOT
    Optional map of plain-text environment variables injected into the Cursor
    integration container at launch (StackGen provider >= 0.1.17). Use for
    non-sensitive overrides such as proxy URLs or feature toggles. The Cursor
    API key already flows through `sg_secret`/`secret_ref_ids`.
  EOT
  type        = map(string)
  default     = {}
}
