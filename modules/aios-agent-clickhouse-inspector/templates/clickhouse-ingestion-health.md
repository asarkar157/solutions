Assess ClickHouse ingestion throughput and identify bottlenecks.

## Steps

1. Recent inserts: `SELECT event_time, query_duration_ms, written_rows, written_bytes FROM system.query_log WHERE type = 'QueryFinish' AND query LIKE 'INSERT%' ORDER BY event_time DESC LIMIT 20`
2. Insert throughput: `SELECT toStartOfMinute(event_time) as minute, count() as inserts, sum(written_rows) as total_rows FROM system.query_log WHERE type = 'QueryFinish' AND query LIKE 'INSERT%' AND event_time > now() - INTERVAL 1 HOUR GROUP BY minute ORDER BY minute DESC`
3. Pending mutations: `SELECT * FROM system.mutations WHERE is_done = 0`
4. Failed inserts: `SELECT event_time, exception, substring(query, 1, 100) FROM system.query_log WHERE type = 'ExceptionWhileProcessing' AND query LIKE 'INSERT%' AND event_date >= today() - 1 ORDER BY event_time DESC LIMIT 10`
5. Check whether merges are keeping up with inserts (cross-reference with parts-merge diagnostics).
6. **Assessment:** Sustained insert failures plus growing parts indicates an ingestion bottleneck.
