# =============================================================================
# Scenario: episodic-memory
# =============================================================================
# Pre-sales pitch: "Agents remember lessons across sessions — when they search."
# Foundation + policies + one memory-enabled agent. No integrations required.
# See ./README.md for the two-act talk track and property glossary.

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

resource "sg_agent" "memory_tutor" {
  name        = "memory-tutor"
  description = "Teaches Guild episodic memory: memory_store and memory_search in agent:memory-tutor namespace."
  persona     = file("${path.module}/personas/memory-tutor.md")
  model_names = compact(module.foundation.model_names)

  knowledge = {
    memory_enabled = true
  }
}

resource "sg_agent_policy_attachment" "memory_tutor_dangerous_ops" {
  agent_name = sg_agent.memory_tutor.name
  policy_id  = module.policies.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_budget" "memory_tutor" {
  agent_name  = sg_agent.memory_tutor.name
  limit_usd   = var.agent_budget_usd
  period_type = "daily"
}
