variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
}

variable "policy_ids" {
  type = object({ dangerous_ops = string })
}

variable "integration_names" {
  type    = map(string)
  default = {}
}

variable "agent_budget" {
  type    = number
  default = 15
}
