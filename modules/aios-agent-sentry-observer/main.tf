terraform {
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.17, < 0.2.0"
    }
  }
}

locals {
  suffix     = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"
  agent_name = "sentry-observer${local.suffix}"

  resolved_sentry_integration_name = trimspace(var.existing_sentry_integration_name)
}

# ============================================================================
# Sentry Observer Module
# ============================================================================
# Dedicated Sentry observability agent for inspecting errors, stack traces
# and incident tracking.

resource "sg_agent" "sentry_observer" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/sentry-observer.md")
  model_names = compact(var.model_names)

  integrations = [local.resolved_sentry_integration_name]
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
