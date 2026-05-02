Identify and analyze slow queries from the ClickHouse query log.

## Steps

1. Find slowest queries (7 days): `SELECT event_time, query_duration_ms, read_rows, formatReadableSize(read_bytes), substring(query, 1, 200) FROM system.query_log WHERE event_date >= today() - 7 AND type = 'QueryFinish' ORDER BY query_duration_ms DESC LIMIT 20`
2. Find most resource-intensive queries: `SELECT event_time, query_duration_ms, peak_memory_usage, read_rows FROM system.query_log WHERE event_date >= today() - 1 AND type = 'QueryFinish' ORDER BY peak_memory_usage DESC LIMIT 10`
3. Check for blocking queries: look for queries with elapsed above 60s in `system.processes`
4. Check query frequency: `SELECT substring(query, 1, 100) as q, count() as cnt, avg(query_duration_ms) as avg_ms FROM system.query_log WHERE event_date >= today() - 1 AND type = 'QueryFinish' GROUP BY q ORDER BY cnt DESC LIMIT 10`
5. Flag queries exceeding 10 seconds or reading more than 100M rows as potential optimization targets.
6. **Output:** Top slow queries, frequency analysis, optimization recommendations.
