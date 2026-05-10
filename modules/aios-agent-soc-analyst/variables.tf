variable "integration_names" {
  description = "Map of integration names to use for this module (e.g., aws, github, slack, datadog, splunk)"
  type        = map(string)
  default     = {}
}

variable "model_names" {
  description = "Map of models available to use (e.g., claude_sonnet, gpt4o)"
  type        = map(string)
}

variable "agent_budget" {
  description = "The daily budget limit in USD for the SOC Analyst agent"
  type        = number
  default     = 25.0
}

variable "policy_ids" {
  description = "Map of policy IDs to attach to the agent (e.g., dangerous_ops, read_only)"
  type        = map(string)
  default     = {}
}
