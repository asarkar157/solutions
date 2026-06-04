variable "stackgen_url" {
  type = string
}

variable "stackgen_token" {
  type      = string
  sensitive = true
}

variable "stackgen_project_id" {
  type = string
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
  type    = string
  default = "us-east-1"
}

variable "aws_stackgen_trust_arns" {
  type = list(string)
}

variable "github_token" {
  type      = string
  sensitive = true
}
