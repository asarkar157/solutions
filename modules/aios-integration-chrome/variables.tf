variable "integration_name" {
  description = "Name of the Guild integration resource."
  type        = string
  default     = "chrome-browser"
}

variable "description" {
  description = "Description for the integration."
  type        = string
  default     = "Headless Chrome browser automation: navigate pages, take screenshots, inspect console/network, run performance traces, and evaluate JavaScript."
}

variable "integration_image" {
  description = "Container image for the Chrome integration sidecar."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-chrome:main"
}

variable "scope" {
  description = "Integration scope (PROJECT or ORGANIZATION)."
  type        = string
  default     = "PROJECT"
}

variable "enabled" {
  description = "Whether the integration is enabled."
  type        = bool
  default     = true
}

variable "allowed_domains" {
  description = <<-EOT
    Comma-separated list of domains the agent is allowed to navigate to.
    Empty means all domains are allowed (except blocked internal IPs and schemes).
    Example: "example.com,mycompany.io,staging.app.com"
  EOT
  type        = string
  default     = ""
}

variable "max_tabs" {
  description = "Maximum number of concurrent browser tabs."
  type        = number
  default     = 5

  validation {
    condition     = var.max_tabs >= 1 && var.max_tabs <= 20
    error_message = "max_tabs must be between 1 and 20."
  }
}

variable "session_timeout" {
  description = "Maximum session duration as a Go duration string (e.g. 30m, 1h)."
  type        = string
  default     = "30m"
}

variable "enable_response_body" {
  description = "Whether to expose full network response bodies (default: headers only)."
  type        = bool
  default     = false
}

variable "env_vars" {
  description = <<-EOT
    Optional map of extra environment variables injected into the Chrome
    container. Use for non-sensitive overrides.
  EOT
  type        = map(string)
  default     = {}
}
