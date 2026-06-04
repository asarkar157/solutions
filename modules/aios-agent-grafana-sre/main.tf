terraform {
  required_version = ">= 1.5"
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", # spawn_contracts / workflow metadata (provider >= 0.1.21).
    version = ">= 0.1.25, < 0.2.0" }
  }
}

locals {
  module_prefix = "grafana-sre"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name = "grafana-observability-sre${local.suffix}"

  sop_service_health_name  = "grafana-service-health-pass${local.suffix}"
  sop_alert_noise_name     = "grafana-alert-noise-check${local.suffix}"
  sop_golden_signals_name  = "grafana-four-golden-signals${local.suffix}"
  sop_slo_name             = "grafana-slo-error-budget-review${local.suffix}"
  sop_dora_name            = "grafana-dora-delivery-visibility${local.suffix}"
  sop_change_failure_name  = "grafana-change-failure-correlation${local.suffix}"
  sop_restore_signals_name = "grafana-restore-time-signals${local.suffix}"
  sop_red_use_name         = "grafana-red-use-workload${local.suffix}"

  grafana_integration_name = "${local.module_prefix}-grafana${local.suffix}"

  resolved_grafana_integration_name = coalesce(
    trimspace(var.existing_grafana_integration_name) != "" ? var.existing_grafana_integration_name : null,
    try(module.grafana_integration[0].integration_name, null),
    local.grafana_integration_name,
  )
}

module "grafana_integration" {
  count  = trimspace(var.existing_grafana_integration_name) == "" ? 1 : 0
  source = "../aios-integration-grafana"

  integration_name   = local.grafana_integration_name
  existing_secret_id = var.grafana_secret_id
  description        = "Grafana integration owned by the ${local.agent_name} agent (Loki/Mimir/Tempo + alert/dashboard queries)."
}

# =============================================================================
# Grafana Observability SRE Agent Module
# =============================================================================

resource "sg_agent" "grafana_sre" {
  name         = local.agent_name
  persona      = file("${path.module}/personas/grafana-sre.md")
  model_names  = compact(var.model_names)
  integrations = [local.resolved_grafana_integration_name]
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
  name        = local.sop_service_health_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-service-health-pass.md", {}))
}

resource "sg_runbook_sop" "alert_noise_check" {
  name        = local.sop_alert_noise_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-alert-noise-check.md", {}))
}

resource "sg_runbook_sop" "four_golden_signals" {
  name        = local.sop_golden_signals_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-four-golden-signals.md", {}))
}

resource "sg_runbook_sop" "slo_error_budget" {
  name        = local.sop_slo_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-slo-error-budget-review.md", {}))
}

resource "sg_runbook_sop" "dora_visibility" {
  name        = local.sop_dora_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-dora-delivery-visibility.md", {}))
}

resource "sg_runbook_sop" "change_failure_correlation" {
  name        = local.sop_change_failure_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-change-failure-correlation.md", {}))
}

resource "sg_runbook_sop" "restore_time_signals" {
  name        = local.sop_restore_signals_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-restore-time-signals.md", {}))
}

resource "sg_runbook_sop" "red_use_workload" {
  name        = local.sop_red_use_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/grafana-red-use-workload.md", {}))
}
