variable "stackgen_url" {
  description = "Base URL of the StackGen / Guild tenant."
  type        = string
}

variable "stackgen_token" {
  description = "StackGen personal access token."
  type        = string
  sensitive   = true
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

variable "grafana_server" {
  description = "Base URL of the prospect's Grafana server (https://...). Required."
  type        = string
}

variable "grafana_token" {
  description = "Grafana service-account token (read scope is enough)."
  type        = string
  sensitive   = true
}

variable "slack_bot_token" {
  description = "Slack Bot Token. Required for this scenario — the whole point is the Slack RCA post."
  type        = string
  sensitive   = true
}
