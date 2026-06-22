variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant (no trailing slash)."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen personal access token."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "Optional StackGen project / org ID."
  type        = string
  default     = ""
}

variable "agent_name" {
  description = "Existing Guild agent to boost with AWS, GitHub, and optional remote runner. Import into sg_agent.sre_boost before first apply."
  type        = string

  validation {
    condition     = trimspace(var.agent_name) != ""
    error_message = "agent_name must be a non-empty existing Guild agent name."
  }
}

variable "aws_role_arn" {
  description = <<-EOT
    Optional customer-account IAM role ARN already allowlisted on the StackGen bastion (not the bastion role ARN from data.sg_vault_aws_config). When empty, this root skips the AWS integration and only wires GitHub (+ optional remote runner). Update trust policy and permissions in your account only — do not change IAM in the bastion account.
  EOT
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "Default AWS region for the new AWS integration."
  type        = string
  default     = "us-east-1"
}

variable "github_token" {
  description = "GitHub PAT for a new GitHub integration."
  type        = string
  sensitive   = true

  validation {
    condition     = trimspace(var.github_token) != ""
    error_message = "github_token is required."
  }
}

variable "create_remote_runner" {
  description = "Register sg_remote_runner and bind the new GitHub/AWS vault secrets for aiden-runner."
  type        = bool
  default     = true
}

variable "remote_runner_name" {
  description = "Guild remote runner name (create or lookup)."
  type        = string
  default     = "sre-boost-runner"
}

variable "runner_docker_image" {
  description = "aiden-runner image for the Docker start command output. Image ENTRYPOINT is `aiden-runner start` — registration flags are appended after the image name."
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-aiden-runner:main"
}

variable "enable_ubuntu_kubectl" {
  description = "Attach Ubuntu CLI integration with kubectl for ai.dev / poc-eval pod RCA. Also bind a kubernetes integration in the SRE app dashboard so k8s_connected=true."
  type        = bool
  default     = false
}
