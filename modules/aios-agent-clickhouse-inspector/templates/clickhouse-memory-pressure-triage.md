Assess memory pressure and OOM risk in ClickHouse.

## Steps

1. Current memory usage: `SELECT metric, value FROM system.metrics WHERE metric = 'MemoryTracking'`
2. Memory limit: `SELECT name, value FROM system.settings WHERE name = 'max_memory_usage'`
3. Peak memory queries: `SELECT event_time, peak_memory_usage, query_duration_ms, substring(query, 1, 150) FROM system.query_log WHERE peak_memory_usage > 1000000000 AND event_date >= today() - 1 ORDER BY peak_memory_usage DESC LIMIT 10`
4. Memory by query type: `SELECT type, count() as cnt, formatReadableSize(avg(peak_memory_usage)) as avg_peak FROM system.query_log WHERE event_date >= today() - 1 GROUP BY type`
5. Check for memory-related errors: `SELECT event_time, exception, substring(query, 1, 100) FROM system.query_log WHERE exception LIKE '%MEMORY_LIMIT%' AND event_date >= today() - 7 ORDER BY event_time DESC LIMIT 10`
6. **Risk:** Memory above 85% of max means OOM risk. Recommend identifying and optimizing high-memory queries; consider scaling.
