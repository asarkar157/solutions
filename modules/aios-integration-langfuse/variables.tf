variable "langfuse_public_key" {
  description = "Langfuse project public key"
  type        = string
}

variable "langfuse_secret_key" {
  description = "Langfuse project secret key"
  type        = string
  sensitive   = true
}

variable "langfuse_host" {
  description = "Langfuse API host (e.g. https://cloud.langfuse.com)"
  type        = string
  default     = "https://cloud.langfuse.com"
}

variable "integration_name" {
  description = "Name of the Guild integration resource"
  type        = string
  default     = "langfuse-integration"
}

variable "description" {
  description = "Description for the integration"
  type        = string
  default     = "Langfuse LLM observability integration for trace analysis, cost monitoring, and quality scoring"
}

variable "scope" {
  description = "Guild integration scope (e.g. PROJECT)"
  type        = string
  default     = "PROJECT"
}

variable "enabled" {
  description = "Whether the Guild integration is enabled"
  type        = bool
  default     = true
}

variable "integration_image" {
  description = "Container image for the Langfuse Guild integration sidecar"
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-langfuse:main"
}

variable "env" {
  description = <<-EOT
    Optional map of plain-text environment variables injected into the
    Langfuse integration container at launch (StackGen provider >= 0.1.17).
    Use for non-sensitive overrides such as proxy URLs, sampling toggles, or
    region flags. Sensitive values (public/secret keys) should go through
    `sg_secret` and be referenced via `secret_ref_ids`.
  EOT
  type        = map(string)
  default     = {}
}
