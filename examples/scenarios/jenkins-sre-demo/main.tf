# =============================================================================
# Scenario: jenkins-sre-demo
# =============================================================================
# Pre-sales pitch: "Show how Aiden connects to Jenkins, triggers builds, and
# is protected by OPA policy guardrails."
#
# Wires foundation + policies + Jenkins + custom Jenkins gate policy + Jenkins SRE agent.
# See ./README.md for the talk track.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.25, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
}

# -----------------------------------------------------------------------------
# Layer 0 — Foundation & Policies
# -----------------------------------------------------------------------------

module "foundation" {
  source = "../../../modules/aios-foundation"

  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id

  llm_api_keys = {
    openai    = var.openai_api_key
    anthropic = var.anthropic_api_key
    gemini    = var.gemini_api_key
  }
}

module "policies" {
  source = "../../../modules/aios-policies"

  create_policies = {
    azure_tool_governance  = false
    google_tool_governance = false
    langfuse_observability = false
  }
}

# Custom Jenkins Trigger Safety Policy defined directly in the scenario
resource "sg_policy" "jenkins_gate" {
  name        = "jenkins-trigger-safety-gate"
  description = "Requires human-in-the-loop approval to trigger any production-related pipeline in Jenkins"
  type        = "intervention"
  rego_source = file("${path.module}/policies/jenkins-gate.rego")
}

# -----------------------------------------------------------------------------
# Layer 1 — Integrations
# -----------------------------------------------------------------------------

module "jenkins_integration" {
  source = "../../../modules/aios-integration-jenkins"

  integration_name   = var.jenkins_integration_name
  jenkins_base_url   = var.jenkins_base_url
  jenkins_username   = var.jenkins_username
  jenkins_token      = var.jenkins_token
  jenkins_mcp_url    = var.jenkins_mcp_url
  existing_secret_id = var.existing_jenkins_secret_id
}

module "slack_integration" {
  count  = trimspace(var.slack_bot_token) != "" ? 1 : 0
  source = "../../../modules/aios-integration-slack"

  slack_bot_token = var.slack_bot_token
}

# -----------------------------------------------------------------------------
# Layer 2 — Agents
# -----------------------------------------------------------------------------

resource "sg_agent" "jenkins_sre" {
  name        = var.agent_name
  persona     = file("${path.module}/personas/jenkins-sre.md")
  model_names = compact(module.foundation.model_names)

  integrations = compact([
    module.jenkins_integration.integration_name,
    length(module.slack_integration) > 0 ? module.slack_integration[0].integration_name : ""
  ])
}

# Attach OPA Policies to the Jenkins Agent
resource "sg_agent_policy_attachment" "jenkins_danger_gate" {
  agent_name = sg_agent.jenkins_sre.name
  policy_id  = module.policies.policy_ids.dangerous_ops
}

resource "sg_agent_policy_attachment" "jenkins_production_gate" {
  agent_name = sg_agent.jenkins_sre.name
  policy_id  = sg_policy.jenkins_gate.id
}
