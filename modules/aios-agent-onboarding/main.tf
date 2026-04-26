terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = "~> 0.1.0" }
  }
}

resource "sg_agent" "onboarding_assistant" {
  name        = "onboarding-assistant"
  persona     = file("${path.module}/personas/onboarding-assistant.md")
  model_names = compact([var.model_names.claude_sonnet, var.model_names.gpt4o])

  hitl = { always_allowed = ["web_search", "note", "read_notes"] }

  integrations = compact([
    lookup(var.integration_names, "slack", "") != "" ? var.integration_names.slack : null,
    lookup(var.integration_names, "github", "") != "" ? var.integration_names.github : null,
    lookup(var.integration_names, "linear", "") != "" ? var.integration_names.linear : null,
    lookup(var.integration_names, "google", "") != "" ? var.integration_names.google : null,
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
  description = "Guide new developer through local env setup. Steps: 1) Verify prerequisites (Git, Docker, Node/Go), 2) Clone required repos, 3) Configure environment variables, 4) Run bootstrap scripts, 5) Verify build and tests pass, 6) Setup IDE extensions."
}

resource "sg_runbook_sop" "access_provisioning" {
  name        = "access-provisioning-checklist"
  description = "Verify and provision developer access. Steps: 1) Check GitHub org membership, 2) Verify repo access, 3) Check cloud console access, 4) Verify monitoring dashboard access, 5) Confirm Slack channel membership, 6) Create access requests for missing permissions."
}

resource "sg_runbook_sop" "codebase_orientation" {
  name        = "codebase-orientation"
  description = "Orient developer to the codebase. Steps: 1) Explain high-level architecture and service boundaries, 2) Walk through key directories and modules, 3) Explain deployment pipeline and environments, 4) Review coding standards and PR process, 5) Identify relevant documentation."
}

resource "sg_workflow" "developer_onboarding" {
  name        = "developer-onboarding"
  domain      = "people-ops"
  description = "Automated developer onboarding pipeline: environment setup, access provisioning, and codebase orientation."

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
    { stage_id = "access-check", agent_ref = sg_agent.onboarding_assistant.name, runbook_refs = [sg_runbook_sop.access_provisioning.name] },
    { stage_id = "env-setup", agent_ref = sg_agent.onboarding_assistant.name, stage_depends_on = ["access-check"], runbook_refs = [sg_runbook_sop.environment_setup.name] },
    { stage_id = "codebase-tour", agent_ref = sg_agent.onboarding_assistant.name, stage_depends_on = ["env-setup"], runbook_refs = [sg_runbook_sop.codebase_orientation.name] },
  ]
}
