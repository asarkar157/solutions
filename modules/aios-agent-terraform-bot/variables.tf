variable "model_names" {
  description = "Map of model keys to actual deployed model names"
  type = object({
    gpt4o         = string
    claude_sonnet = string
    gemini_flash  = string
  })
}

variable "policy_ids" {
  description = "Map of policy IDs to attach to the agents"
  type = object({
    dangerous_ops = string
  })
}

variable "integration_names" {
  description = "Map of integration names available to this module"
  type = object({
    github     = string
    ubuntu_cli = string
  })
}
