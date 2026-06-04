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

variable "github_token" {
  type      = string
  sensitive = true
}

variable "audit_repo_list" {
  type    = list(string)
  default = []
}
