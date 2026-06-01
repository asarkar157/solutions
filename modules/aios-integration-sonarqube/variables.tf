variable "server_url" {
  description = "SonarQube server URL (e.g. https://sonar.example.com). Stored in Vault as `server_url`."
  type        = string
  default     = ""
}

variable "token" {
  description = "SonarQube user token for API access."
  type        = string
  sensitive   = true
  default     = ""
}

variable "existing_secret_id" {
  description = "Optional existing `sg_secret` ID with SonarQube credentials (`server_url`, `token`)."
  type        = string
  default     = ""
}

variable "integration_name" {
  type    = string
  default = "sonarqube-integration"
}

variable "description" {
  type    = string
  default = "SonarQube integration for quality gates, branch analysis, and new-issue correlation."
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
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-sonarqube:main"
}

variable "env" {
  type    = map(string)
  default = {}
}
