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
variable "agent_names" {
  description = "External agent names for cross-domain workflow stage bindings"
  type = object({
    github_agent  = string
    grafana_agent = string
    aws_agent     = string
  })
}
variable "agent_budget" {
  type    = number
  default = 25
}

