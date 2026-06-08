variable "integration_name" {
  type    = string
  default = "ubuntu-cli"
}

variable "integration_image" {
  type    = string
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-ubuntu-cli:main"
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
    Supported values: tofu, terraform, awscli, kubectl, helm, gcloud, az, gh, git, curl, jq, gdown, cce, python3-pip.
    Example: ["tofu", "gh", "git"]
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for t in var.install_tools : contains(["tofu", "terraform", "awscli", "kubectl", "helm", "gcloud", "az", "gh", "git", "curl", "jq", "gdown", "cce", "python3-pip"], t)
    ])
    error_message = "Each element must be one of: tofu, terraform, awscli, kubectl, helm, gcloud, az, gh, git, curl, jq, gdown, cce, python3-pip."
  }
}

variable "pip_packages" {
  description = <<-EOT
    Python packages to pip-install at container startup (user-local, via pre_launch.sh INSTALL_PIP_PACKAGES).
    Pass full pip specs including version pins, e.g. ["cfn-lint>=1.19.0", "checkov==3.2.340"]. Install Ruby gems (e.g. cfn-nag) separately via container image or runtime scripts.
  EOT
  type        = list(string)
  default     = []
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
