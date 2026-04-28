variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
}
variable "policy_ids" {
  type = object({ dangerous_ops = string, sre_remediation = optional(string, "") })
}
variable "github_token" {
  type      = string
  sensitive = true
  default   = ""
}
variable "agent_budget" {
  type    = number
  default = 15
}

variable "workflow_approve" {
  description = "When true, Guild approves the workflow draft via API after apply (no pending approval in the UI)."
  type        = bool
  default     = true
}
