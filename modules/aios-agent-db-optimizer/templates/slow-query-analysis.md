# Slow Query Analysis SOP

1. **Identify**: Retrieve the top 10 slowest queries from the past 24 hours.
2. **Explain**: Run `EXPLAIN ANALYZE` on these queries using representative parameters.
3. **Analyze**: Look for Sequential Scans, excessive Nested Loops, or missing table statistics.
4. **Recommend**: Formulate a DDL script (e.g., `CREATE INDEX CONCURRENTLY`) and estimate the performance gain.
