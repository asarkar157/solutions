variable "stackgen_url" {
  type        = string
  description = "Guild API base URL (e.g. https://main.dev.stackgen.com or http://localhost:8088)."
}

variable "stackgen_token" {
  type        = string
  sensitive   = true
  description = "StackGen personal access token."
}

variable "stackgen_project_id" {
  type        = string
  default     = ""
  description = "Org/project UUID when required by your Guild tenant."
}

variable "stackgen_insecure" {
  type        = bool
  default     = false
  description = "Set true for plaintext HTTP to stackgen_url (local dev-edge only)."
}

variable "name_prefix" {
  type        = string
  default     = "integration-gaps-smoke"
  description = "Prefix for integration and vault secret names."
}

variable "enable_kubernetes" {
  type    = bool
  default = false
}

variable "kubernetes_role_arn" {
  type    = string
  default = ""
}

variable "kubernetes_region" {
  type    = string
  default = ""
}

variable "kubernetes_cluster_name" {
  type    = string
  default = ""
}

variable "enable_sonarqube" {
  type    = bool
  default = false
}

variable "sonarqube_server_url" {
  type    = string
  default = ""
}

variable "sonarqube_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "enable_firehydrant" {
  type    = bool
  default = false
}

variable "firehydrant_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "firehydrant_base_url" {
  type    = string
  default = ""
}

variable "enable_digitalocean" {
  type    = bool
  default = false
}

variable "digitalocean_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "enable_coralogix" {
  type    = bool
  default = false
}

variable "coralogix_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "coralogix_base_url" {
  type    = string
  default = "https://api.coralogix.com"
}

variable "enable_civo" {
  type    = bool
  default = false
}

variable "civo_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "enable_newrelic" {
  type    = bool
  default = false
}

variable "newrelic_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "newrelic_region" {
  type    = string
  default = "us"
}

variable "enable_circleci" {
  type    = bool
  default = false
}

variable "circleci_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "enable_squadcast" {
  type    = bool
  default = false
}

variable "squadcast_refresh_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "squadcast_region" {
  type    = string
  default = "us"
}
