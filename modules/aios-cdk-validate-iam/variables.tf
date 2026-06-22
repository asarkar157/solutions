variable "role_name" {
  description = "IAM role name in the customer account for CDK validate."
  type        = string
  default     = "stackgen-cdk-validate"
}

variable "trusted_assumer_arns" {
  description = "Vault bastion roleArn from GET /integration/aws/config (Principal.AWS in trust policy)."
  type        = list(string)
}

variable "external_id" {
  description = "Workspace externalId from Vault AWS config API."
  type        = string
  default     = ""
}
