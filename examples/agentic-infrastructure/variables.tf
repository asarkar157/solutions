variable "stackgen_url" {
  description = "StackGen API base URL (no trailing slash). eg: https://cloud.stackgen.com"
  type        = string
}

variable "stackgen_token" {
  description = "StackGen API bearer token (same family of credential used for Terraform provider \"sg\" and platform MCP)."
  type        = string
  sensitive   = true
}

variable "stackgen_project_id" {
  description = "StackGen project ID"
  type        = string
}

variable "openai_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "anthropic_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "gemini_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "aws_region" {
  description = "AWS region for provider \"aws\" and the StackGen AWS Guild integration metadata."
  type        = string
  default     = "us-east-1"
}

variable "aws_integration_role_name" {
  description = "Name of the IAM role created for StackGen to assume (Vault stores its ARN on apply)."
  type        = string
  default     = "stackgen-aws-mcp-integration"
}

variable "aws_stackgen_trust_arns" {
  description = "IAM principal ARN(s) allowed to sts:AssumeRole into the integration role—use the value(s) from StackGen when you connect AWS. Ignored if aws_integration_assume_role_policy_json is set."
  type        = list(string)
  default     = []
}

variable "aws_integration_assume_role_policy_json" {
  description = "Optional full IAM assume-role trust policy JSON. When set (non-empty), overrides aws_stackgen_trust_arns."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition = (
      length(var.aws_stackgen_trust_arns) > 0 ||
      try(length(trimspace(var.aws_integration_assume_role_policy_json)) > 0, false)
    )
    error_message = "Set aws_stackgen_trust_arns to one or more principal ARNs from StackGen AWS setup, or set aws_integration_assume_role_policy_json to the full trust policy JSON."
  }
}

variable "aws_integration_managed_policy_arns" {
  description = "AWS managed policy ARNs to attach to the integration role (least privilege for your org)."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}

variable "aws_integration_role_tags" {
  description = "Tags for aws_iam_role.stackgen_aws_integration."
  type        = map(string)
  default     = {}
}

variable "github_token" {
  description = "GitHub PAT for SDLC GitHub SCM agent and (when non-empty) registers the GitHub Guild integration plus repo-to-iac workflows (repository-to-iac, repo-scan-appstack-github-export). Leave empty to skip GitHub integration and repository IaC module."
  type        = string
  sensitive   = true
  default     = ""
}

variable "linear_integration_name" {
  description = "Guild Linear MCP integration name for SDLC project-manager (e.g. linear-integration). Empty skips attaching Linear tools to that agent."
  type        = string
  default     = ""
}

variable "gcp_integration_name" {
  description = "Guild GCP / Google MCP integration name for cloud-infrastructure-engineer (e.g. google-integration). Empty skips."
  type        = string
  default     = ""
}

variable "slack_integration_name" {
  description = "Guild Slack MCP integration name for cloud-infrastructure-engineer (e.g. slack-integration). Empty skips."
  type        = string
  default     = ""
}

variable "create_stackgen_mcp_integrations" {
  description = "When true, create one sg_secret + one sg_guild_integration for StackGen Consumer MCP (stackgen_url + /api/mcp/user; Vault transport streamable_http)."
  type        = bool
  default     = true
}

variable "stackgen_mcp_secret_name" {
  description = "Vault secret name for the MCP endpoint (Other/mcp: transport, url, headers)."
  type        = string
  default     = "stackgen-mcp-credentials"
}

variable "enable_entitlement_guard" {
  description = "When true and github_token is set, enables CCE on repo-to-iac for entitlement-sized IAM recommendations before infra apply."
  type        = bool
  default     = true
}

variable "stackgen_mcp_integration_name" {
  description = "Guild integration name for the StackGen MCP server."
  type        = string
  default     = "stackgen-mcp"
}
