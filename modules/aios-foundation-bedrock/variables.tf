variable "stackgen_url" {
  description = "Base URL of the StackGen platform. Configure the root module provider \"sg\" with stackgen_url set to this value."
  type        = string
}

variable "stackgen_token" {
  description = "Bearer token for StackGen API authentication. Configure the root module provider \"sg\" with stackgen_token set to this value."
  type        = string
  sensitive   = true
  default     = ""
}

variable "stackgen_insecure" {
  description = "Allow plaintext HTTP connections (for local development only). Must match the root provider \"sg\" insecure setting if set."
  type        = bool
  default     = false
}

variable "project_id" {
  description = "Default project (organization) ID for scoped Guild/API calls. Must match the root provider \"sg\" project_id when set (preferred over deprecated org_id)."
  type        = string
  default     = ""
}

variable "org_id" {
  description = "Deprecated: use project_id on the root provider \"sg\" instead. Retained for backward compatibility with older root modules."
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Optional prefix for all resource names (prevents collisions in multi-tenant deployments)"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for the Bedrock provider host field (e.g. us-east-1). Also used to derive the cross-region inference profile prefix when inference_profile_id is unset."
  type        = string
  default     = "us-east-1"
}

variable "inference_profile_id" {
  description = <<-EOT
    Bedrock model_id for Claude Sonnet 4.6. Use the cross-region inference profile form
    (e.g. us.anthropic.claude-sonnet-4-6) — required for Sonnet 4.6 on Bedrock. When empty,
    defaults to "{prefix}.anthropic.claude-sonnet-4-6" where prefix is derived from aws_region.
  EOT
  type        = string
  default     = ""
}

variable "provider_name" {
  description = "Guild model provider name for Bedrock"
  type        = string
  default     = "bedrock"
}

variable "model_name" {
  description = "Guild-registered model name agents reference in model_names (e.g. claude-sonnet-bedrock)"
  type        = string
  default     = "claude-sonnet-bedrock"
}

variable "good_for_task" {
  description = "Guild task hint for the registered model (planning, tool_calling, efficiency, general_task)"
  type        = string
  default     = "planning"
}

variable "bedrock_auth" {
  description = <<-EOT
    How Guild authenticates to Bedrock. Set use_iam_role = true when Guild runs on AWS with an
    instance/task role that has bedrock:InvokeModel (and list permissions). Otherwise supply
    static AWS keys in the vault secret metadata (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, …).
  EOT
  type = object({
    use_iam_role          = optional(bool, false)
    aws_access_key_id     = optional(string, "")
    aws_secret_access_key = optional(string, "")
    aws_session_token     = optional(string, "")
  })
  sensitive = true
  default   = {}
}
