variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
}
variable "policy_ids" {
  type = object({ dangerous_ops = string })
}
variable "integration_names" {
  description = "Guild integration names to attach (slack, github, linear, google). Empty string or omitted keys are skipped."
  type = object({
    slack  = optional(string, "")
    github = optional(string, "")
    linear = optional(string, "")
    google = optional(string, "")
  })
  default = {}
}
variable "agent_budget" {
  type    = number
  default = 10
}

variable "workflow_approve" {
  description = "When true, Guild approves the workflow draft via API after apply."
  type        = bool
  default     = true
}
