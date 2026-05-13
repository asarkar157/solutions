variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)

  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

variable "policy_ids" {
  description = "Policy IDs from the root module for agent policy attachments"
  type = object({
    dangerous_ops          = string
    infra_mutations        = optional(string, "")
    k8s_production         = optional(string, "")
    github_protected       = optional(string, "")
    datadog_alert_triage   = optional(string, "")
    github_org_restriction = optional(string, "")
  })
}

variable "secret_names" {
  description = "Secret names from the root module"
  type = object({
    gemini_vault = optional(string, "")
  })
  default = { gemini_vault = "" }
}

variable "integration_names" {
  description = <<-EOT
    Guild integration names keyed for attachment:
    - aws_production — AWS MCP (e.g. aws-production)
    - stackgen_mcp — Consumer MCP for stackgen-mcp_* tools (e.g. stackgen-mcp)
    - gcp_production — GCP / Google gcloud MCP (e.g. google-integration)
    - slack — Slack MCP (e.g. slack-integration)
    - github_scm — GitHub SCM (e.g. github-integration); used when github_token is non-empty. Defaults to github-integration if omitted.
  EOT
  type        = map(string)
  default     = {}
}

variable "sre_agent_names" {
  description = "Agent names from the SRE module needed for cross-domain execution plans"
  type = object({
    sre_risk_posture = string
  })
}

variable "sre_runbook_names" {
  description = "Runbook names from the SRE module needed for cross-domain execution plans"
  type = object({
    deployment_rollback = string
    ssl_cert_renewal    = optional(string, "")
  })
}

variable "sre_evidence_checklist_names" {
  description = <<-EOT
    Evidence checklist names managed outside this module (typically from `module.<sre>.workflow_names` or the `sg_evidence_checklist.name` values in `aios-agent-sre`).
    When `change_validation` is non-empty, `sg_workflow.release_pipeline` sets `evidence_checklist_ref` to that name so release proof-of-work aligns with the SRE module.
    Leave empty (default) to omit a workflow-level checklist on the release pipeline; `developer-request-intake` always uses the checklist defined in this module.
  EOT
  type = object({
    change_validation = optional(string, "")
  })
  default = { change_validation = "" }
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "linear_mcp_integration_name" {
  description = "Name of the Linear MCP integration resource (empty if not enabled)"
  type        = string
  default     = ""
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

