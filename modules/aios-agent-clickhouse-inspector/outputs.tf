output "agent_name" {
  description = "ClickHouse inspector agent name for cross-module references"
  value       = sg_agent.clickhouse_inspector.name
}
