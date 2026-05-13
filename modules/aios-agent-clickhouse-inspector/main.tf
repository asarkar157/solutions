terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen", version = ">= 0.1.13, < 0.2.0" }
  }
}

# ============================================================================
# ClickHouse Inspector Module
# ============================================================================
# Dedicated ClickHouse inspection agent with deep system-table expertise.
# Designed for read-only diagnostics: cluster health, slow queries,
# parts/merge analysis, memory pressure, and ingestion throughput.
#
# Uses a user-provided MCP server image (BYOI pattern) that wraps the
# official mcp-clickhouse server. Vault injects connection credentials
# (host, user, password) at launch time.

# ============================================================================
# Agent
# ============================================================================

resource "sg_agent" "clickhouse_inspector" {
  name        = "clickhouse-inspector"
  persona     = file("${path.module}/personas/clickhouse-inspector.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]

  integrations = [var.integration_names.clickhouse]
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
  name        = "clickhouse-cluster-health-assessment"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-cluster-health-assessment.md", {}))
}

resource "sg_runbook_sop" "clickhouse_slow_queries" {
  name        = "clickhouse-slow-query-analysis"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-slow-query-analysis.md", {}))
}

resource "sg_runbook_sop" "clickhouse_parts_merges" {
  name        = "clickhouse-parts-merge-diagnostics"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-parts-merge-diagnostics.md", {}))
}

resource "sg_runbook_sop" "clickhouse_memory_pressure" {
  name        = "clickhouse-memory-pressure-triage"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-memory-pressure-triage.md", {}))
}

resource "sg_runbook_sop" "clickhouse_ingestion_health" {
  name        = "clickhouse-ingestion-health"
  approve     = true
  description = trimspace(templatefile("${path.module}/templates/clickhouse-ingestion-health.md", {}))
}
