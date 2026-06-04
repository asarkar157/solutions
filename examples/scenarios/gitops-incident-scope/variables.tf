variable "stackgen_url" {
  type = string
}

variable "stackgen_token" {
  type      = string
  sensitive = true
}

variable "stackgen_project_id" {
  type    = string
  default = ""
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

variable "gitlab_secret_id" {
  type = string
}

variable "argocd_secret_id" {
  type = string
}

variable "sonarqube_secret_id" {
  type = string
}

variable "aws_secret_id" {
  type = string
}

variable "slack_secret_id" {
  type = string
}

variable "git_repo" {
  type    = string
  default = ""
}
