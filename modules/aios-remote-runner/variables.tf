variable "name" {
  description = "Guild remote runner name (sg_remote_runner.name). Used for create and for data.sg_remote_runner lookup."
  type        = string

  validation {
    condition     = trimspace(var.name) != ""
    error_message = "name must be a non-empty remote runner name."
  }
}

variable "create_runner" {
  description = <<-EOT
    When true, registers a new `sg_remote_runner` (StackGen provider >= 0.1.23). The runner connects outbound to
    mothership (`provider stackgen_url`) — suitable for on-prem / VPC / firewall-restricted environments.
    When false, only looks up an existing runner by `name` at plan time.
  EOT
  type        = bool
  default     = false
}

variable "description" {
  description = "Description for the runner when `create_runner` is true. Ignored on lookup-only mode."
  type        = string
  default     = "Aiden remote runner for Guild tool execution behind the customer firewall (outbound-only to mothership)."
}

variable "labels" {
  description = "Optional labels on the runner when `create_runner` is true (affinity routing)."
  type        = map(string)
  default     = {}
}
