# =============================================================================
# Scenario: grafana-github-rca
# =============================================================================
# Pre-sales pitch: "A Grafana alert fires — can you tie it to a bad deploy?"
# Grafana alert -> Aiden correlates telemetry with GitHub commits and blame ->
# writes the RCA back to Grafana -> opens a policy-gated GitHub fix PR.
# The alert ingest, investigation, and RCA UI live in the stackgen-sre-app
# (installed separately). This root provisions policy guardrails and Grafana /
# GitHub / Slack integrations the stackgen-sre-app binds to. It does not
# register LLM models — the SRE app install owns investigator model wiring.
#
# See ./README.md for the talk track and the manual stackgen-sre-app + Grafana
# webhook wiring steps.

terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = {
      source  = "releases.stackgen.com/stackgen/stackgen"
      version = ">= 0.1.27, < 0.2.0"
    }
  }
}

provider "sg" {
  stackgen_url   = var.stackgen_url
  stackgen_token = var.stackgen_token
  project_id     = var.stackgen_project_id != "" ? var.stackgen_project_id : null
  insecure       = var.stackgen_insecure
}

# Layer 0 — full guardrail set. The SRE investigator's remediation / fix-PR
# steps are gated by the HITL + write-protection policies.
module "policies" {
  source = "../../../modules/aios-policies"
}

# -----------------------------------------------------------------------------
# Layer 1 — integrations the demo flow depends on.
# -----------------------------------------------------------------------------

# Grafana MCP integration: read-only telemetry the investigator queries during
# RCA. (Grafana -> SRE app alert ingest is a contact-point webhook, configured
# in the Grafana UI against the SRE app ingest URL — see README.)
module "grafana_integration" {
  source = "../../../modules/aios-integration-grafana"

  grafana_server = var.grafana_server
  grafana_token  = var.grafana_token
}

# GitHub SCM integration with `repo` scope: discovery context, commit/blame
# correlation during RCA, and the fix PR the investigator opens from the RCA.
module "github_integration" {
  source = "../../../modules/aios-integration-github"

  github_token = var.github_token
}

# Slack (optional): incident channel + approval prompts.
module "slack_integration" {
  count  = trimspace(var.slack_bot_token) != "" ? 1 : 0
  source = "../../../modules/aios-integration-slack"

  slack_bot_token = var.slack_bot_token
}

# Layer 1b — bind integrations to the installed stackgen-sre-app (catalog slug "sre").
# Requires the SRE app to already be installed in this org (see README).
module "sre_app_bindings" {
  count  = var.enable_sre_app_bindings ? 1 : 0
  source = "../../../modules/aios-sre-app-bindings"

  integration_names = sort(compact([
    module.grafana_integration.integration_name,
    module.github_integration.integration_name,
    length(module.slack_integration) > 0 ? module.slack_integration[0].integration_name : "",
  ]))

  alert_webhooks = var.enable_grafana_alert_webhook ? [{
    source           = "grafana"
    integration      = module.grafana_integration.integration_name
    auto_investigate = var.grafana_alert_auto_investigate
  }] : []
}
