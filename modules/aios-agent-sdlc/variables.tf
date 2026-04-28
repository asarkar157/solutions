variable "model_names" {
  description = "Named LLM model references from the root module"
  type = object({
    gpt4o         = string
    claude_sonnet = string
  })
}

variable "policy_ids" {
  description = "Policy IDs from the root module for agent policy attachments"
  type = object({
    dangerous_ops          = string
    infra_mutations        = optional(string, "")
    k8s_production         = optional(string, "")
    github_protected       = optional(string, "")
    datadog_alert_triage   = optional(string, "")
    github_org_restriction = optional(string, "")
  })
}

variable "secret_names" {
  description = "Secret names from the root module"
  type = object({
    gemini_vault = optional(string, "")
  })
  default = { gemini_vault = "" }
}

variable "integration_names" {
  description = "Containerized integration names from the root module"
  type        = map(string)
  default     = {}
}

variable "sre_agent_names" {
  description = "Agent names from the SRE module needed for cross-domain execution plans"
  type = object({
    sre_risk_posture = string
  })
}

variable "sre_runbook_names" {
  description = "Runbook names from the SRE module needed for cross-domain execution plans"
  type = object({
    deployment_rollback = string
    ssl_cert_renewal    = optional(string, "")
  })
}

variable "sre_evidence_checklist_names" {
  description = "Evidence checklist names from the SRE module"
  type = object({
    change_validation = optional(string, "")
  })
  default = { change_validation = "" }
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "linear_mcp_integration_name" {
  description = "Name of the Linear MCP integration resource (empty if not enabled)"
  type        = string
  default     = ""
}

variable "workflow_approve" {
  description = "When true, Guild approves workflow drafts via API after apply."
  type        = bool
  default     = true
}
