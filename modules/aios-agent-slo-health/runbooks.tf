# =============================================================================
# Runbooks — review workflow
# =============================================================================

resource "sg_runbook_sop" "fetch_openslo_specs" {
  name        = local.sop_fetch_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-fetch-openslo-specs.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "scan_grafana_config" {
  name        = local.sop_scan_config_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-scan-grafana-config.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "detect_config_drift" {
  name        = local.sop_detect_drift_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-detect-config-drift.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "query_slo_metrics" {
  name        = local.sop_query_metrics_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-query-slo-metrics.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "assess_error_budget" {
  name        = local.sop_assess_budget_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-assess-error-budget.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "compose_slo_digest" {
  name        = local.sop_compose_digest_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-compose-slo-digest.md.tftpl", local.runbook_template_vars))
}

# =============================================================================
# Runbooks — bootstrap workflow
# =============================================================================

resource "sg_runbook_sop" "fetch_existing_catalog" {
  count       = var.enable_slo_bootstrap_workflow ? 1 : 0
  name        = local.sop_fetch_catalog_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-fetch-existing-catalog.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "scan_grafana_signals" {
  count       = var.enable_slo_bootstrap_workflow ? 1 : 0
  name        = local.sop_scan_signals_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-scan-grafana-signals.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "propose_slo_candidates" {
  count       = var.enable_slo_bootstrap_workflow ? 1 : 0
  name        = local.sop_propose_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-propose-slo-candidates.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "validate_promql" {
  count       = var.enable_slo_bootstrap_workflow ? 1 : 0
  name        = local.sop_validate_promql_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-validate-promql.md"))
}

resource "sg_runbook_sop" "draft_openslo_yaml" {
  count       = var.enable_slo_bootstrap_workflow ? 1 : 0
  name        = local.sop_draft_yaml_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-draft-openslo-yaml.md"))
}

resource "sg_runbook_sop" "preview_proposals" {
  count       = var.enable_slo_bootstrap_workflow ? 1 : 0
  name        = local.sop_preview_proposals_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-preview-proposals.md"))
}

resource "sg_runbook_sop" "open_slo_pr" {
  count       = var.enable_slo_bootstrap_workflow ? 1 : 0
  name        = local.sop_open_slo_pr_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-open-slo-pr.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "notify_pr_opened" {
  count       = var.enable_slo_bootstrap_workflow ? 1 : 0
  name        = local.sop_notify_bootstrap_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-notify-pr-opened.md.tftpl", local.runbook_template_vars))
}

# =============================================================================
# Runbooks — drift reconcile workflow
# =============================================================================

resource "sg_runbook_sop" "fetch_catalog_and_grafana" {
  count       = var.enable_slo_drift_reconcile_workflow ? 1 : 0
  name        = local.sop_fetch_drift_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-fetch-catalog-and-grafana.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "classify_drift_items" {
  count       = var.enable_slo_drift_reconcile_workflow ? 1 : 0
  name        = local.sop_classify_drift_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-classify-drift-items.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "draft_reconcile_yaml" {
  count       = var.enable_slo_drift_reconcile_workflow ? 1 : 0
  name        = local.sop_draft_reconcile_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-draft-reconcile-yaml.md"))
}

resource "sg_runbook_sop" "preview_drift_fixes" {
  count       = var.enable_slo_drift_reconcile_workflow ? 1 : 0
  name        = local.sop_preview_drift_name
  approve     = true
  description = trimspace(file("${path.module}/templates/runbook-preview-drift-fixes.md"))
}

resource "sg_runbook_sop" "open_drift_pr" {
  count       = var.enable_slo_drift_reconcile_workflow ? 1 : 0
  name        = local.sop_open_drift_pr_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-open-drift-pr.md.tftpl", local.runbook_template_vars))
}

resource "sg_runbook_sop" "notify_drift_pr" {
  count       = var.enable_slo_drift_reconcile_workflow ? 1 : 0
  name        = local.sop_notify_drift_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/runbook-notify-drift-pr.md.tftpl", local.runbook_template_vars))
}
