variable "integration_name" {
  type    = string
  default = "ubuntu-cli"
}

variable "integration_image" {
  type    = string
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-ubuntu:main"
}

variable "secret_ref_ids" {
  description = <<-EOT
    Optional list of sg_secret IDs to inject into the Ubuntu container at launch.
    Use this to attach cloud-provider credentials (e.g. AWS via STS assume-role)
    so that tools like `tofu plan` or `aws` CLI work inside the shell container.
  EOT
  type        = list(string)
  default     = []
}

variable "install_tools" {
  description = <<-EOT
    List of CLI tools to install at container startup via the pre_launch.sh hook.
    Supported values: tofu, terraform, awscli, kubectl, helm, gcloud, az.
    Example: ["tofu", "awscli", "kubectl"]
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for t in var.install_tools : contains(["tofu", "terraform", "awscli", "kubectl", "helm", "gcloud", "az"], t)
    ])
    error_message = "Each element must be one of: tofu, terraform, awscli, kubectl, helm, gcloud, az."
  }
}

variable "env_vars" {
  description = <<-EOT
    Optional map of extra environment variables to inject into the Ubuntu
    container. These are passed as plain-text env vars (not secrets).
    Example: { "AWS_DEFAULT_REGION" = "us-west-2" }
  EOT
  type        = map(string)
  default     = {}
}
