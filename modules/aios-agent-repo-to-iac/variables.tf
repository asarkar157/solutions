variable "model_names" {
  description = "Named LLM model references from aios-foundation"
  type = object({
    gpt4o         = string
    claude_sonnet = string
  })
}

variable "policy_ids" {
  description = "Policy IDs from aios-policies (typically dangerous_ops)"
  type = object({
    dangerous_ops = string
  })
}

variable "github_integration_name" {
  description = "Guild integration name for the GitHub MCP integration (from aios-integration-github)."
  type        = string
}

variable "stackgen_mcp_integration_name" {
  description = "Optional: Guild integration name for StackGen hosted MCP (SSE). Empty skips attaching StackGen MCP."
  type        = string
  default     = ""
}

variable "agent_budget_usd_daily" {
  description = "Daily USD budget cap for the repository IaC architect agent."
  type        = number
  default     = 25
}
