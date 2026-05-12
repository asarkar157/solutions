terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.9, < 0.2.0" }
  }
}

resource "sg_agent" "onboarding_assistant" {
  name        = "onboarding-assistant"
  persona     = file("${path.module}/personas/onboarding-assistant.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  hitl = { always_allowed = ["web_search", "note", "read_notes"] }

  integrations = compact([
    var.integration_names.slack != "" ? var.integration_names.slack : null,
    var.integration_names.github != "" ? var.integration_names.github : null,
    var.integration_names.linear != "" ? var.integration_names.linear : null,
    var.integration_names.google != "" ? var.integration_names.google : null,
  ])
}

resource "sg_agent_budget" "onboarding" {
  agent_name  = sg_agent.onboarding_assistant.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.onboarding_assistant.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_runbook_sop" "environment_setup" {
  name        = "developer-environment-setup"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/developer-environment-setup.md", {}))
}

resource "sg_runbook_sop" "access_provisioning" {
  name        = "access-provisioning-checklist"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/access-provisioning-checklist.md", {}))
}

resource "sg_runbook_sop" "codebase_orientation" {
  name        = "codebase-orientation"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/codebase-orientation.md", {}))
}

resource "sg_workflow" "developer_onboarding" {
  name        = "developer-onboarding"
  domain      = "people-ops"
  description = trimspace(templatefile("${path.module}/templates/workflow-developer-onboarding.md", {}))
  approve     = true

  required_inputs = ["developer_name", "team"]
  optional_inputs = ["role", "start_date"]

  example_queries = [
    "Onboard a new developer to the backend team",
    "Set up the dev environment for a new frontend engineer",
    "Check if the new hire has all required access",
    "Walk the new developer through our codebase architecture",
  ]

  stages = [
    { stage_id = "access-check", description = "Verify and provision all required access.", required = true },
    { stage_id = "env-setup", description = "Guide through local development environment setup.", required = true },
    { stage_id = "codebase-tour", description = "Architecture walkthrough and coding standards review.", required = true },
  ]

  stage_bindings = [
    { stage_id = "access-check", agent_ref = sg_agent.onboarding_assistant.name, runbook_refs = [sg_runbook_sop.access_provisioning.name], skill_refs = concat(["peopleops-access-provisioning"], try(var.workflow_skill_refs["developer-onboarding::access-check"], [])) },
    { stage_id = "env-setup", agent_ref = sg_agent.onboarding_assistant.name, stage_depends_on = ["access-check"], runbook_refs = [sg_runbook_sop.environment_setup.name], skill_refs = concat(["peopleops-dev-environment-setup"], try(var.workflow_skill_refs["developer-onboarding::env-setup"], [])) },
    { stage_id = "codebase-tour", agent_ref = sg_agent.onboarding_assistant.name, stage_depends_on = ["env-setup"], runbook_refs = [sg_runbook_sop.codebase_orientation.name], skill_refs = concat(["peopleops-codebase-orientation"], try(var.workflow_skill_refs["developer-onboarding::codebase-tour"], [])) },
  ]
}
