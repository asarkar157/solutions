terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.13, < 0.2.0" }
  }
}

variable "integration_names" {
  type    = map(string)
  default = {}
}

variable "model_names" {
  type = map(string)
}

resource "sg_agent" "incident_commander" {
  name    = "incident-commander"
  persona = file("${path.module}/personas/incident-commander.md")
  model_names = compact([
    lookup(var.model_names, "gpt4o", ""),
    lookup(var.model_names, "claude_sonnet", ""),
    lookup(var.model_names, "gemini_flash", "")
  ])
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

variable "workflow_skill_refs" {
  description = <<-EOT
    Optional Guild skill_refs for sg_workflow stage_bindings (load_skill hints so stages stay on playbook).
    Keys: "incident-orchestration::<stage_id>" (acknowledge, diagnose, mitigate, postmortem). Each value is appended after module defaults.
  EOT
  type        = map(list(string))
  default     = {}
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  count      = lookup(var.policy_ids, "dangerous_ops", "") != "" ? 1 : 0
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

  stages = [
    { stage_id = "acknowledge", description = "Ack PagerDuty alert and create incident channel.", required = true },
    { stage_id = "diagnose", description = "Pull metrics and identify failing component.", required = true },
    { stage_id = "mitigate", description = "Suggest or apply mitigation (e.g., rollback).", required = true },
    { stage_id = "postmortem", description = "Draft incident timeline and postmortem document.", required = true },
  ]

  stage_bindings = [
    {
      stage_id     = "acknowledge"
      agent_ref    = sg_agent.incident_commander.name
      runbook_refs = [sg_runbook_sop.major_incident.name]
      skill_refs   = concat(["sre-incident-acknowledge"], try(var.workflow_skill_refs["incident-orchestration::acknowledge"], []))
    },
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
    {
      stage_id         = "postmortem"
      agent_ref        = sg_agent.incident_commander.name
      stage_depends_on = ["mitigate"]
      skill_refs       = concat(["sre-incident-postmortem"], try(var.workflow_skill_refs["incident-orchestration::postmortem"], []))
    },
  ]
}
