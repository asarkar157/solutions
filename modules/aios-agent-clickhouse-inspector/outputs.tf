output "agent_name" {
  description = "ClickHouse inspector agent name for cross-module references"
  value       = sg_agent.clickhouse_inspector.name
}

output "clickhouse_integration_name" {
  description = "Resolved ClickHouse Guild integration name."
  value       = local.resolved_clickhouse_integration_name
}

output "runbook_sop_names" {
  description = "Names of the ClickHouse inspector SOPs."
  value = {
    cluster_health   = sg_runbook_sop.clickhouse_cluster_health.name
    slow_queries     = sg_runbook_sop.clickhouse_slow_queries.name
    parts_merges     = sg_runbook_sop.clickhouse_parts_merges.name
    memory_pressure  = sg_runbook_sop.clickhouse_memory_pressure.name
    ingestion_health = sg_runbook_sop.clickhouse_ingestion_health.name
  }
}
