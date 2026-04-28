variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
}
variable "policy_ids" {
  type = object({ dangerous_ops = string, container_shell_hitl = optional(string, "") })
}
variable "integration_names" {
  type    = map(string)
  default = {}
}
variable "linear_readonly_tools" {
  type    = list(string)
  default = []
}

