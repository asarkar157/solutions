variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
}

variable "policy_ids" {
  type = object({ dangerous_ops = string })
}

variable "integration_name" {
  description = "AWS integration name from the integration module"
  type        = string
  default     = "aws-production"
}

variable "agent_budget" {
  type    = number
  default = 20
}

variable "workflow_approve" {
  description = "When true, Guild approves workflow drafts via API after apply."
  type        = bool
  default     = true
}
