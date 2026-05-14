terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.18, < 0.2.0" }
  }
}

locals {
  module_prefix = "onboarding"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name                    = "onboarding-assistant${local.suffix}"
  workflow_name                 = "developer-onboarding${local.suffix}"
  sop_env_setup_name            = "developer-environment-setup${local.suffix}"
  sop_access_provisioning_name  = "access-provisioning-checklist${local.suffix}"
  sop_codebase_orientation_name = "codebase-orientation${local.suffix}"

  slack_integration_name  = "${local.module_prefix}-slack${local.suffix}"
  github_integration_name = "${local.module_prefix}-github${local.suffix}"
  linear_integration_name = "${local.module_prefix}-linear${local.suffix}"

  provision_slack  = trimspace(var.slack_secret_id) != "" && trimspace(var.existing_slack_integration_name) == ""
  provision_github = trimspace(var.github_secret_id) != "" && trimspace(var.existing_github_integration_name) == ""
  provision_linear = trimspace(var.linear_credential_provider_id) != "" && trimspace(var.existing_linear_integration_name) == ""

  resolved_slack_integration_name = trimspace(var.existing_slack_integration_name) != "" ? var.existing_slack_integration_name : (
    local.provision_slack ? module.slack_integration[0].integration_name : ""
  )
  resolved_github_integration_name = trimspace(var.existing_github_integration_name) != "" ? var.existing_github_integration_name : (
    local.provision_github ? module.github_integration[0].integration_name : ""
  )
  resolved_linear_integration_name = trimspace(var.existing_linear_integration_name) != "" ? var.existing_linear_integration_name : (
    local.provision_linear ? module.linear_integration[0].integration_name : ""
  )
  resolved_google_integration_name = trimspace(var.existing_google_integration_name)
}

module "slack_integration" {
  count  = local.provision_slack ? 1 : 0
  source = "../aios-integration-slack"

  integration_name   = local.slack_integration_name
  existing_secret_id = var.slack_secret_id
}

module "github_integration" {
  count  = local.provision_github ? 1 : 0
  source = "../aios-integration-github"

  integration_name   = local.github_integration_name
  existing_secret_id = var.github_secret_id
}

module "linear_integration" {
  count  = local.provision_linear ? 1 : 0
  source = "../aios-integration-linear"

  integration_name       = local.linear_integration_name
  credential_provider_id = var.linear_credential_provider_id
}

resource "sg_agent" "onboarding_assistant" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/onboarding-assistant.md")
  model_names = compact(var.model_names)

  hitl = { always_allowed = ["web_search", "note", "read_notes"] }

  integrations = compact([
    local.resolved_slack_integration_name,
    local.resolved_github_integration_name,
    local.resolved_linear_integration_name,
    local.resolved_google_integration_name,
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
  name        = local.sop_env_setup_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/developer-environment-setup.md", {}))
}

resource "sg_runbook_sop" "access_provisioning" {
  name        = local.sop_access_provisioning_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/access-provisioning-checklist.md", {}))
}

resource "sg_runbook_sop" "codebase_orientation" {
  name        = local.sop_codebase_orientation_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/codebase-orientation.md", {}))
}

resource "sg_workflow" "developer_onboarding" {
  name        = local.workflow_name
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
