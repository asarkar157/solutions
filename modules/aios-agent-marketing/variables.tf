variable "model_names" {
  description = "Named LLM model references"
  type = object({
    gpt4o         = string
    claude_sonnet = string
  })
}

variable "policy_ids" {
  description = "Policy IDs for agent policy attachments"
  type = object({
    dangerous_ops = string
  })
}

