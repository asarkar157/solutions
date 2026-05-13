variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}
variable "policy_ids" {
  type = object({ dangerous_ops = string, data_risk_pii = optional(string, "") })
}
variable "grafana_base_url" {
  description = "Grafana server URL"
  type        = string
}
variable "grafana_api_token" {
  type      = string
  sensitive = true
}
variable "vault_secret_name" {
  type    = string
  default = "grafana-sre-vault"
}
variable "integration_name" {
  type    = string
  default = "grafana-observability"
}
variable "integration_image" {
  type    = string
  default = "ghcr.io/appcd-dev/stackgen-guild-integration-grafana:main"
}
variable "agent_budget" {
  type    = number
  default = 15
}
