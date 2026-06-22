terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.25, < 0.2.0" }
  }
}

variable "integration_names" {
  type    = map(string)
  default = {}
}

variable "model_names" {
  description = "Ordered list of registered model names exposed to this module's agents (highest preference first). Forwarded straight to sg_agent.model_names after compact()."
  type        = list(string)
  default     = ["gpt-5.4-2026-03-05"]
  validation {
    condition     = length(compact(var.model_names)) > 0
    error_message = "model_names must contain at least one non-empty model name."
  }
}

resource "sg_agent" "incident_commander" {
  name        = "incident-commander"
  persona     = file("${path.module}/personas/incident-commander.md")
  model_names = compact(var.model_names)
  integrations = compact([
    lookup(var.integration_names, "pagerduty", ""),
    lookup(var.integration_names, "slack", ""),
    lookup(var.integration_names, "datadog", ""),
  ])
}

variable "policy_ids" {
  type = object({
    dangerous_ops = optional(string, "")
  })
  default = {}
}

variable "policy_create_flags" {
  description = <<-EOT
    Align with module.policies.policy_create_flags when using module.policies. Drives Terraform count
    on the optional dangerous_ops attachment so count does not depend on unknown policy_ids.
  EOT
  type = object({
    dangerous_ops = optional(bool, true)
  })
  default = {}
}

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "incident-orchestration::<stage_id>" (acknowledge, diagnose, mitigate, postmortem). Each value is appended after module defaults.
  EOT
  type        = map(list(string))
  default     = {}
}

variable "pagerduty_ack_webhook_url" {
  description = <<-EOT
    Optional PagerDuty Events API v2 URL for deterministic incident acknowledgement.
    When non-empty, the incident-orchestration workflow inserts a `pagerduty-ack`
    webhook stage (action_type = "webhook") before the LLM-driven acknowledge stage.
    The stage POSTs a PagerDuty-compatible ack event — zero LLM cost, sub-second.
    Typical value: https://events.pagerduty.com/v2/enqueue
  EOT
  type        = string
  default     = ""
}

variable "resolution_notification_webhook_url" {
  description = <<-EOT
    Optional HTTP(S) URL for deterministic incident resolution notifications.
    When non-empty, the incident-orchestration workflow appends a `notify-resolution`
    webhook stage after the postmortem, POSTing the incident timeline + resolution summary.
  EOT
  type        = string
  default     = ""
}

locals {
  pagerduty_ack_enabled     = trimspace(var.pagerduty_ack_webhook_url) != ""
  resolution_notify_enabled = trimspace(var.resolution_notification_webhook_url) != ""
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  count      = try(var.policy_create_flags.dangerous_ops, true) ? 1 : 0
  agent_name = sg_agent.incident_commander.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_runbook_sop" "major_incident" {
  name        = "major-incident-response"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/major-incident.md", {}))
}

resource "sg_workflow" "incident_orchestration" {
  name        = "incident-orchestration"
  domain      = "sre"
  description = "End-to-end orchestration of SEV1/SEV2 incidents."
  approve     = true

  stages = concat(
    local.pagerduty_ack_enabled ? [{ stage_id = "pagerduty-ack", description = "Auto-acknowledge the PagerDuty alert via a deterministic HTTP POST \u2014 zero LLM cost, sub-second.", required = false }] : [],
    [
      { stage_id = "acknowledge", description = "Ack PagerDuty alert and create incident channel.", required = true },
      { stage_id = "diagnose", description = "Pull metrics and identify failing component.", required = true },
      { stage_id = "mitigate", description = "Suggest or apply mitigation (e.g., rollback).", required = true },
      { stage_id = "mitigation-gate", description = "Evaluate mitigation outcome: re-diagnose on failure (GO_BACK), or proceed to postmortem when recovery looks solid.", required = false },
      { stage_id = "postmortem", description = "Draft incident timeline and postmortem document.", required = true },
    ],
    local.resolution_notify_enabled ? [{ stage_id = "notify-resolution", description = "POST the incident timeline + resolution summary to the configured webhook endpoint.", required = false }] : [],
  )

  stage_bindings = concat(
    local.pagerduty_ack_enabled ? [{
      stage_id    = "pagerduty-ack"
      action_type = "webhook"
      action_config = {
        url             = var.pagerduty_ack_webhook_url
        method          = "POST"
        timeout_seconds = 10
      }
    }] : [],
    [
      merge(
        {
          stage_id     = "acknowledge"
          agent_ref    = sg_agent.incident_commander.name
          runbook_refs = [sg_runbook_sop.major_incident.name]
          skill_refs   = concat(["sre-incident-acknowledge"], try(var.workflow_skill_refs["incident-orchestration::acknowledge"], []))
        },
        local.pagerduty_ack_enabled ? { stage_depends_on = ["pagerduty-ack"] } : {},
      ),
      {
        stage_id         = "diagnose"
        agent_ref        = sg_agent.incident_commander.name
        stage_depends_on = ["acknowledge"]
        skill_refs       = concat(["sre-incident-diagnose"], try(var.workflow_skill_refs["incident-orchestration::diagnose"], []))
      },
      {
        stage_id         = "mitigate"
        agent_ref        = sg_agent.incident_commander.name
        stage_depends_on = ["diagnose"]
        skill_refs       = concat(["sre-incident-mitigate"], try(var.workflow_skill_refs["incident-orchestration::mitigate"], []))
      },
      # navigation_gate: LLM decides whether mitigation succeeded or needs re-diagnosis.
      # If failed → GO_BACK to diagnose (max 2 retries). If recovery looks solid → proceed to postmortem.
      {
        stage_id         = "mitigation-gate"
        action_type      = "navigation_gate"
        stage_depends_on = ["mitigate"]
        action_config = {
          allowed_transitions = jsonencode(["diagnose", "postmortem"])
          max_goback_count    = 2
          navigation_prompt   = "If the mitigation output indicates failure, error, or timeout, go back to diagnose. If it indicates success, proceed to postmortem."
        }
      },
      {
        stage_id         = "postmortem"
        agent_ref        = sg_agent.incident_commander.name
        stage_depends_on = ["mitigation-gate"]
        skill_refs       = concat(["sre-incident-postmortem"], try(var.workflow_skill_refs["incident-orchestration::postmortem"], []))
      },
    ],
    local.resolution_notify_enabled ? [{
      stage_id         = "notify-resolution"
      action_type      = "webhook"
      stage_depends_on = ["postmortem"]
      action_config = {
        url             = var.resolution_notification_webhook_url
        method          = "POST"
        timeout_seconds = 10
      }
    }] : [],
  )
}
