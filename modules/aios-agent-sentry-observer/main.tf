terraform {
  required_providers {
    sg = {
      source = "releases.stackgen.com/stackgen/stackgen"
    }
  }
}

# ============================================================================
# Sentry Observer Module
# ============================================================================
# Dedicated Sentry observability agent for inspecting errors, stack traces
# and incident tracking.

resource "sg_agent" "sentry_observer" {
  name        = "sentry-observer"
  persona     = file("${path.module}/personas/sentry-observer.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gemini_flash]

  integrations = [var.integration_names.sentry]
}

resource "sg_agent_budget" "sentry_observer" {
  agent_name  = sg_agent.sentry_observer.name
  limit_usd   = 5
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "sentry_dangerous_ops" {
  agent_name = sg_agent.sentry_observer.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "sentry_data_risk" {
  agent_name = sg_agent.sentry_observer.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_agent_policy_attachment" "sentry_observability" {
  agent_name = sg_agent.sentry_observer.name
  policy_id  = var.policy_ids.sentry_observability
  enabled    = true
}
