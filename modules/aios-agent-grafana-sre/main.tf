terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.0.20" }
  }
}

# =============================================================================
# Grafana Observability SRE Agent Module
# =============================================================================
# Self-contained: creates its own vault secret, integration, and agent with
# 8 observability runbooks following Google SRE and DORA practices.

resource "sg_secret" "grafana_vault" {
  name        = var.vault_secret_name
  description = "Grafana API credentials for observability SRE agent"
  category    = "CloudProvider"
  subcategory = "grafana"
  metadata = {
    base_url  = var.grafana_base_url
    api_token = var.grafana_api_token
  }
}

resource "sg_guild_integration" "grafana" {
  name           = var.integration_name
  type           = "grafana"
  scope          = "PROJECT"
  secret_ref_ids = [sg_secret.grafana_vault.id]
  enabled        = true
  description    = "Grafana observability SRE integration against ${var.grafana_base_url}"

  image = { name = var.integration_image }
}

resource "sg_agent" "grafana_sre" {
  name         = "grafana-observability-sre"
  persona      = file("${path.module}/personas/grafana-sre.md")
  model_names  = [var.model_names.claude_sonnet, var.model_names.gpt4o]
  integrations = [sg_guild_integration.grafana.name]
}

resource "sg_agent_budget" "grafana_sre" {
  agent_name  = sg_agent.grafana_sre.name
  limit_usd   = var.agent_budget
  period_type = "daily"
}

resource "sg_agent_policy_attachment" "dangerous_ops" {
  agent_name = sg_agent.grafana_sre.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "data_risk" {
  count      = var.policy_ids.data_risk_pii != "" ? 1 : 0
  agent_name = sg_agent.grafana_sre.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

# --- Runbooks (8 total) ---

resource "sg_runbook_sop" "service_health_pass" {
  name        = "grafana-service-health-pass"
  description = "Quick health pass using Grafana dashboards and alerts. Steps: 1) List dashboards matching service, 2) Fetch dashboard JSON and note key panels, 3) Retrieve firing alerts, 4) Summarize overall status."
}

resource "sg_runbook_sop" "alert_noise_check" {
  name        = "grafana-alert-noise-check"
  description = "Assess alert actionability vs noise. Steps: 1) Group alerts by rule name, 2) Flag duplicates, 3) Note sustained vs flapping patterns, 4) Output actionable vs backlog alerts."
}

resource "sg_runbook_sop" "four_golden_signals" {
  name        = "grafana-four-golden-signals"
  description = "Google SRE golden signals pass (latency, traffic, errors, saturation). Steps: 1) Locate service dashboard, 2-5) Analyze each signal, 6) Output status table."
}

resource "sg_runbook_sop" "slo_error_budget" {
  name        = "grafana-slo-error-budget-review"
  description = "Review SLI/SLO and error-budget posture. Steps: 1) Find SLO panels, 2) Note compliance and burn, 3) Compare multi-window burn, 4) Cross-check alerts, 5) Output budget health."
}

resource "sg_runbook_sop" "dora_visibility" {
  name        = "grafana-dora-delivery-visibility"
  description = "DORA-aligned visibility: lead time, deployment frequency, change failure rate from Grafana dashboards."
}

resource "sg_runbook_sop" "change_failure_correlation" {
  name        = "grafana-change-failure-correlation"
  description = "Tie changes to user-observable failure using Grafana views and alerts. Steps: 1) Identify change window, 2) Compare before/after, 3) Map alerts to symptoms, 4) Assess correlation, 5) Output finding."
}

resource "sg_runbook_sop" "restore_time_signals" {
  name        = "grafana-restore-time-signals"
  description = "Strengthen MTTR by validating Grafana shows what on-call needs for detection, location, and recovery verification."
}

resource "sg_runbook_sop" "red_use_workload" {
  name        = "grafana-red-use-workload"
  description = "Structured workload review combining RED (rate, errors, duration) with USE (utilization, saturation, errors) per service."
}
