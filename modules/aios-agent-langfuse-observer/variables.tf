variable "model_names" {
  type = object({ gpt4o = string, claude_sonnet = string, gemini_flash = string })
}

variable "policy_ids" {
  type = object({
    dangerous_ops          = string
    data_risk_pii          = optional(string, "")
    langfuse_observability = optional(string, "")
  })
}

variable "integration_names" {
  description = <<-EOT
    Guild integration names. Must include "langfuse". Any other keys attach extra integrations
    on the same observer agent (e.g. grafana, slack, linear, github, aws, gcp, clickhouse) so
    runbooks can correlate traces with infra, post digests, file tickets, or check deploys.
  EOT
  type        = map(string)
  validation {
    condition     = try(var.integration_names["langfuse"], "") != ""
    error_message = "integration_names must contain a non-empty \"langfuse\" entry."
  }
}

variable "agent_name" {
  description = "sg_agent name. Override when deploying multiple observers (e.g. per team or Langfuse project)."
  type        = string
  default     = "langfuse-ai-quality-observer"
}

variable "workflow_name" {
  description = "sg_workflow name for the AI Ops Health Scorecard."
  type        = string
  default     = "ai-ops-health-scorecard"
}

variable "workflow_domain" {
  type    = string
  default = "observability"
}

variable "workflow_approve" {
  description = "Whether the workflow requires human approval before completion."
  type        = bool
  default     = true
}

variable "runbook_name_prefix" {
  description = "Prefix for sg_runbook_sop resource names to avoid collisions when this module is instantiated more than once in the same StackGen project."
  type        = string
  default     = "langfuse"
}

variable "additional_example_queries" {
  description = "Extra example_queries appended to the workflow (e.g. team-specific scorecard prompts)."
  type        = list(string)
  default     = []
}

variable "agent_budget" {
  type    = number
  default = 10
}
