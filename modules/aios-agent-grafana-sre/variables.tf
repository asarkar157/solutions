variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
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
