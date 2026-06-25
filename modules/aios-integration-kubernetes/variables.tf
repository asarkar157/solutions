variable "role_arn" {
  description = "IAM role ARN the sidecar assumes to reach the EKS cluster."
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region of the EKS cluster."
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID (`role_arn`, `region`, `cluster_name`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "kubernetes-integration"
}

variable "description" {
  type    = string
  default = "Kubernetes (EKS) integration for read-only kubectl inspection."
}

variable "scope" {
  type    = string
  default = "PROJECT"
}

variable "enabled" {
  type    = bool
  default = true
}

variable "integration_image" {
  type    = string
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-kubernetes:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
