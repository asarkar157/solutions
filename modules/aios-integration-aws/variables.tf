variable "aws_role_arn" {
  description = "AWS IAM Role ARN to assume via Vault"
  type        = string
}

variable "aws_region" {
  description = "Default AWS region"
  type        = string
  default     = "us-east-1"
}

variable "integration_name" {
  description = "Name of the Guild integration resource"
  type        = string
  default     = "aws-production"
}

variable "description" {
  description = "Description for the integration"
  type        = string
  default     = "AWS Integration for autonomous SRE operations using assume role"
}

variable "scope" {
  description = "Integration scope (PROJECT or ORGANIZATION)"
  type        = string
  default     = "PROJECT"
}

variable "enabled" {
  description = "Whether the integration is enabled"
  type        = bool
  default     = true
}

variable "integration_image" {
  description = "Container image for the AWS MCP integration"
  type        = string
  default     = "ghcr.io/appcd-dev/stackgen-guild-integration-aws:main"
}
