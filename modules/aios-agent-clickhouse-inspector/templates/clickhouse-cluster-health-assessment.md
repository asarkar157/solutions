Assess ClickHouse cluster health and resource utilization.

## Steps

1. Verify connectivity: `SELECT version(), uptime()`
2. Check live metrics: `SELECT metric, value FROM system.metrics WHERE metric IN ('Query', 'Merge', 'MemoryTracking', 'OpenFileForRead')`
3. Check async metrics: `SELECT * FROM system.asynchronous_metrics WHERE metric LIKE '%CPU%' OR metric LIKE '%Memory%'`
4. Check table sizes: `SELECT table, formatReadableSize(sum(bytes)) as size, sum(rows) as rows, min(min_date), max(max_date) FROM system.parts WHERE active GROUP BY table ORDER BY sum(bytes) DESC`
5. Check running queries: `SELECT query_id, user, elapsed, read_rows, memory_usage, substring(query, 1, 100) FROM system.processes ORDER BY elapsed DESC LIMIT 10`
6. Check server info: `SELECT name, value FROM system.settings WHERE name IN ('max_memory_usage', 'max_threads', 'max_concurrent_queries')`
7. **Health assessment:** CPU above 80% sustained means overloaded; memory above 85% means OOM risk. Output structured health report.
