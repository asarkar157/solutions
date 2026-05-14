terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.17, < 0.2.0" }
  }
}

locals {
  module_prefix = "clickhouse-inspector"

  suffix = trimspace(var.name_suffix) == "" ? "" : "-${trimspace(var.name_suffix)}"

  agent_name                = "clickhouse-inspector${local.suffix}"
  sop_cluster_health_name   = "clickhouse-cluster-health-assessment${local.suffix}"
  sop_slow_queries_name     = "clickhouse-slow-query-analysis${local.suffix}"
  sop_parts_merges_name     = "clickhouse-parts-merge-diagnostics${local.suffix}"
  sop_memory_pressure_name  = "clickhouse-memory-pressure-triage${local.suffix}"
  sop_ingestion_health_name = "clickhouse-ingestion-health${local.suffix}"

  clickhouse_integration_name = "${local.module_prefix}-clickhouse${local.suffix}"

  # `provision_clickhouse` must be plan-time known (drives `count`).
  # Consumers may forward a computed `clickhouse_secret_id` so we don't
  # inspect it here. The inner aios-integration-clickhouse module surfaces a
  # clear error when both inputs are missing.
  provision_clickhouse = trimspace(var.existing_clickhouse_integration_name) == ""

  resolved_clickhouse_integration_name = trimspace(var.existing_clickhouse_integration_name) != "" ? var.existing_clickhouse_integration_name : (
    local.provision_clickhouse ? module.clickhouse_integration[0].integration_name : ""
  )
}

resource "terraform_data" "integration_required" {
  lifecycle {
    precondition {
      condition     = trimspace(local.resolved_clickhouse_integration_name) != ""
      error_message = "aios-agent-clickhouse-inspector needs a ClickHouse integration: provide either `clickhouse_secret_id` (with `clickhouse_mcp_image`) or `existing_clickhouse_integration_name`."
    }
    precondition {
      condition     = !local.provision_clickhouse || trimspace(var.clickhouse_mcp_image) != ""
      error_message = "clickhouse_mcp_image is required when this module provisions its own ClickHouse integration."
    }
  }
}

module "clickhouse_integration" {
  count  = local.provision_clickhouse ? 1 : 0
  source = "../aios-integration-clickhouse"

  integration_name     = local.clickhouse_integration_name
  existing_secret_id   = var.clickhouse_secret_id
  clickhouse_mcp_image = var.clickhouse_mcp_image
}

# ============================================================================
# ClickHouse Inspector Module
# ============================================================================
# Dedicated ClickHouse inspection agent with deep system-table expertise.
# Designed for read-only diagnostics: cluster health, slow queries,
# parts/merge analysis, memory pressure, and ingestion throughput.

# ============================================================================
# Agent
# ============================================================================

resource "sg_agent" "clickhouse_inspector" {
  name        = local.agent_name
  persona     = file("${path.module}/personas/clickhouse-inspector.md")
  model_names = compact(var.model_names)

  integrations = compact([local.resolved_clickhouse_integration_name])
}

# ============================================================================
# Agent Budget
# ============================================================================

resource "sg_agent_budget" "clickhouse_inspector" {
  agent_name  = sg_agent.clickhouse_inspector.name
  limit_usd   = 10
  period_type = "daily"
}

# ============================================================================
# Policy Attachments
# ============================================================================

resource "sg_agent_policy_attachment" "ch_dangerous_ops" {
  agent_name = sg_agent.clickhouse_inspector.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "ch_data_risk" {
  count      = var.policy_ids.data_risk_pii != "" ? 1 : 0
  agent_name = sg_agent.clickhouse_inspector.name
  policy_id  = var.policy_ids.data_risk_pii
  enabled    = true
}

resource "sg_agent_policy_attachment" "ch_tool_governance" {
  count      = var.policy_ids.azure_tool_governance != "" ? 1 : 0
  agent_name = sg_agent.clickhouse_inspector.name
  policy_id  = var.policy_ids.azure_tool_governance
  enabled    = true
}

# ============================================================================
# Runbook SOPs — Granular ClickHouse Triage Skills
# ============================================================================

resource "sg_runbook_sop" "clickhouse_cluster_health" {
  name        = local.sop_cluster_health_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-cluster-health-assessment.md", {}))
}

resource "sg_runbook_sop" "clickhouse_slow_queries" {
  name        = local.sop_slow_queries_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-slow-query-analysis.md", {}))
}

resource "sg_runbook_sop" "clickhouse_parts_merges" {
  name        = local.sop_parts_merges_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-parts-merge-diagnostics.md", {}))
}

resource "sg_runbook_sop" "clickhouse_memory_pressure" {
  name        = local.sop_memory_pressure_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-memory-pressure-triage.md", {}))
}

resource "sg_runbook_sop" "clickhouse_ingestion_health" {
  name        = local.sop_ingestion_health_name
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-ingestion-health.md", {}))
}
