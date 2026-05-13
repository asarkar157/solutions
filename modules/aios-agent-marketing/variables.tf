variable "model_names" {
  description = "Named LLM model references"
  type = object({
    gpt4o         = string
    claude_sonnet = string
    gemini_flash  = optional(string, "")
  })
}

variable "policy_ids" {
  description = "Policy IDs for agent policy attachments"
  type = object({
    dangerous_ops = string
  })
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "<workflow_name>::<stage_id>" where workflow_name is the sg_workflow.name in this module and stage_id matches the stage.
    Each value is appended after the module defaults for that stage.
  EOT
  type        = map(list(string))
  default     = {}
}
