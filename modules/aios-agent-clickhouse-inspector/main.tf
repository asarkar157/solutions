terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen" }
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
  description = <<-EOT
    Assess ClickHouse cluster health and resource utilization.

    Steps:
    1) Verify connectivity: SELECT version(), uptime()
    2) Check live metrics: SELECT metric, value FROM system.metrics WHERE metric IN ('Query', 'Merge', 'MemoryTracking', 'OpenFileForRead')
    3) Check async metrics: SELECT * FROM system.asynchronous_metrics WHERE metric LIKE '%CPU%' OR metric LIKE '%Memory%'
    4) Check table sizes: SELECT table, formatReadableSize(sum(bytes)) as size, sum(rows) as rows, min(min_date), max(max_date) FROM system.parts WHERE active GROUP BY table ORDER BY sum(bytes) DESC
    5) Check running queries: SELECT query_id, user, elapsed, read_rows, memory_usage, substring(query, 1, 100) FROM system.processes ORDER BY elapsed DESC LIMIT 10
    6) Check server info: SELECT name, value FROM system.settings WHERE name IN ('max_memory_usage', 'max_threads', 'max_concurrent_queries')
    7) Health assessment: CPU >80% sustained = overloaded, memory >85% = OOM risk. Output structured health report.
  EOT
}

resource "sg_runbook_sop" "clickhouse_slow_queries" {
  name        = "clickhouse-slow-query-analysis"
  description = <<-EOT
    Identify and analyze slow queries from the ClickHouse query log.

    Steps:
    1) Find slowest queries (7 days): SELECT event_time, query_duration_ms, read_rows, formatReadableSize(read_bytes), substring(query, 1, 200) FROM system.query_log WHERE event_date >= today() - 7 AND type = 'QueryFinish' ORDER BY query_duration_ms DESC LIMIT 20
    2) Find most resource-intensive queries: SELECT event_time, query_duration_ms, peak_memory_usage, read_rows FROM system.query_log WHERE event_date >= today() - 1 AND type = 'QueryFinish' ORDER BY peak_memory_usage DESC LIMIT 10
    3) Check for blocking queries: Look for queries with elapsed > 60s in system.processes
    4) Check query frequency: SELECT substring(query, 1, 100) as q, count() as cnt, avg(query_duration_ms) as avg_ms FROM system.query_log WHERE event_date >= today() - 1 AND type = 'QueryFinish' GROUP BY q ORDER BY cnt DESC LIMIT 10
    5) Flag queries exceeding 10 seconds or reading more than 100M rows as potential optimization targets.
    6) Output: Top slow queries, frequency analysis, optimization recommendations.
  EOT
}

resource "sg_runbook_sop" "clickhouse_parts_merges" {
  name        = "clickhouse-parts-merge-diagnostics"
  description = <<-EOT
    Diagnose part count issues and merge backlog in ClickHouse.

    Steps:
    1) Check parts per table: SELECT database, table, count() as parts, sum(rows) as total_rows FROM system.parts WHERE active GROUP BY database, table HAVING parts > 50 ORDER BY parts DESC
    2) Check parts per partition (TooManyParts risk): SELECT database, table, partition, count() as parts FROM system.parts WHERE active GROUP BY database, table, partition HAVING parts > 100 ORDER BY parts DESC
    3) Check active merges: SELECT table, count() as merges, sum(rows_read) as rows_merging FROM system.merges GROUP BY table
    4) Check merge backlog: If active merges > 50 or parts > 300/partition, ingestion is at risk.
    5) Check recent part creation rate: SELECT toStartOfMinute(modification_time) as minute, count() as new_parts FROM system.parts WHERE modification_time > now() - INTERVAL 1 HOUR GROUP BY minute ORDER BY minute DESC
    6) Risk assessment: >300 parts/partition = TooManyParts imminent, >200 = warning, <100 = healthy.
  EOT
}

resource "sg_runbook_sop" "clickhouse_memory_pressure" {
  name        = "clickhouse-memory-pressure-triage"
  description = <<-EOT
    Assess memory pressure and OOM risk in ClickHouse.

    Steps:
    1) Current memory usage: SELECT metric, value FROM system.metrics WHERE metric = 'MemoryTracking'
    2) Memory limit: SELECT name, value FROM system.settings WHERE name = 'max_memory_usage'
    3) Peak memory queries: SELECT event_time, peak_memory_usage, query_duration_ms, substring(query, 1, 150) FROM system.query_log WHERE peak_memory_usage > 1000000000 AND event_date >= today() - 1 ORDER BY peak_memory_usage DESC LIMIT 10
    4) Memory by query type: SELECT type, count() as cnt, formatReadableSize(avg(peak_memory_usage)) as avg_peak FROM system.query_log WHERE event_date >= today() - 1 GROUP BY type
    5) Check for memory-related errors: SELECT event_time, exception, substring(query, 1, 100) FROM system.query_log WHERE exception LIKE '%MEMORY_LIMIT%' AND event_date >= today() - 7 ORDER BY event_time DESC LIMIT 10
    6) Risk: memory >85% of max = OOM risk. Recommend: identify and optimize high-memory queries, consider scaling.
  EOT
}

resource "sg_runbook_sop" "clickhouse_ingestion_health" {
  name        = "clickhouse-ingestion-health"
  description = <<-EOT
    Assess ClickHouse ingestion throughput and identify bottlenecks.

    Steps:
    1) Recent inserts: SELECT event_time, query_duration_ms, written_rows, written_bytes FROM system.query_log WHERE type = 'QueryFinish' AND query LIKE 'INSERT%' ORDER BY event_time DESC LIMIT 20
    2) Insert throughput: SELECT toStartOfMinute(event_time) as minute, count() as inserts, sum(written_rows) as total_rows FROM system.query_log WHERE type = 'QueryFinish' AND query LIKE 'INSERT%' AND event_time > now() - INTERVAL 1 HOUR GROUP BY minute ORDER BY minute DESC
    3) Pending mutations: SELECT * FROM system.mutations WHERE is_done = 0
    4) Failed inserts: SELECT event_time, exception, substring(query, 1, 100) FROM system.query_log WHERE type = 'ExceptionWhileProcessing' AND query LIKE 'INSERT%' AND event_date >= today() - 1 ORDER BY event_time DESC LIMIT 10
    5) Check if merges are keeping up with inserts (cross-reference with parts-merge-diagnostics).
    6) Assessment: Sustained insert failures + growing parts = ingestion bottleneck.
  EOT
}
