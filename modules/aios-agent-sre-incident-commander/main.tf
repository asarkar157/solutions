terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.8, < 0.2.0" }
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

resource "sg_agent_policy_attachment" "dangerous_ops" {
  count      = lookup(var.policy_ids, "dangerous_ops", "") != "" ? 1 : 0
  agent_name = sg_agent.incident_commander.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_runbook_sop" "major_incident" {
  name        = "major-incident-response"
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
    { stage_id = "acknowledge", agent_ref = sg_agent.incident_commander.name, runbook_refs = [sg_runbook_sop.major_incident.name] },
    { stage_id = "diagnose", agent_ref = sg_agent.incident_commander.name, stage_depends_on = ["acknowledge"] },
    { stage_id = "mitigate", agent_ref = sg_agent.incident_commander.name, stage_depends_on = ["diagnose"] },
    { stage_id = "postmortem", agent_ref = sg_agent.incident_commander.name, stage_depends_on = ["mitigate"] },
  ]
}
