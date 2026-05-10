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
