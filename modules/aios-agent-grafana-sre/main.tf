terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.13, < 0.2.0" }
  }
}

# =============================================================================
# Grafana Observability SRE Agent Module
# =============================================================================
# Self-contained: creates its own vault secret, integration, and agent with
# 8 observability runbooks following Google SRE and DORA practices.

resource "sg_secret" "grafana_vault" {
  name        = var.vault_secret_name
  description = trimspace(templatefile("${path.module}/templates/secret-grafana-vault.md", {}))
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
  description    = trimspace(templatefile("${path.module}/templates/integration-grafana-description.md.tftpl", { grafana_base_url = var.grafana_base_url }))

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
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-service-health-pass.md", {}))
}

resource "sg_runbook_sop" "alert_noise_check" {
  name        = "grafana-alert-noise-check"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-alert-noise-check.md", {}))
}

resource "sg_runbook_sop" "four_golden_signals" {
  name        = "grafana-four-golden-signals"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-four-golden-signals.md", {}))
}

resource "sg_runbook_sop" "slo_error_budget" {
  name        = "grafana-slo-error-budget-review"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-slo-error-budget-review.md", {}))
}

resource "sg_runbook_sop" "dora_visibility" {
  name        = "grafana-dora-delivery-visibility"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-dora-delivery-visibility.md", {}))
}

resource "sg_runbook_sop" "change_failure_correlation" {
  name        = "grafana-change-failure-correlation"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-change-failure-correlation.md", {}))
}

resource "sg_runbook_sop" "restore_time_signals" {
  name        = "grafana-restore-time-signals"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-restore-time-signals.md", {}))
}

resource "sg_runbook_sop" "red_use_workload" {
  name        = "grafana-red-use-workload"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-red-use-workload.md", {}))
}
