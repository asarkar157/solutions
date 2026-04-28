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

