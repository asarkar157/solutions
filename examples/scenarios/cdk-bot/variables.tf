variable "stackgen_url" {
  type = string
}

variable "stackgen_insecure" {
  type    = bool
  default = false
}

variable "stackgen_token" {
  type      = string
  sensitive = true
}

variable "stackgen_project_id" {
  type    = string
  default = ""
}

variable "github_token" {
  type      = string
  sensitive = true
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

variable "cdk_catalog_repository_full_names" {
  type    = list(string)
  default = []
}

variable "cdk_catalog_issue_label" {
  type    = string
  default = "cdk-construct-request"
}

variable "enable_aws_validation" {
  type    = bool
  default = false
}

variable "existing_aws_integration_name" {
  type    = string
  default = ""
}

variable "aws_role_arn" {
  type    = string
  default = ""
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
