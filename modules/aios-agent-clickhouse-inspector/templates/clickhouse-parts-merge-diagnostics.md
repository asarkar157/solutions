Diagnose part count issues and merge backlog in ClickHouse.

## Steps

1. Check parts per table: `SELECT database, table, count() as parts, sum(rows) as total_rows FROM system.parts WHERE active GROUP BY database, table HAVING parts > 50 ORDER BY parts DESC`
2. Check parts per partition (TooManyParts risk): `SELECT database, table, partition, count() as parts FROM system.parts WHERE active GROUP BY database, table, partition HAVING parts > 100 ORDER BY parts DESC`
3. Check active merges: `SELECT table, count() as merges, sum(rows_read) as rows_merging FROM system.merges GROUP BY table`
4. Check merge backlog: if active merges exceed 50 or parts exceed 300 per partition, ingestion is at risk.
5. Check recent part creation rate: `SELECT toStartOfMinute(modification_time) as minute, count() as new_parts FROM system.parts WHERE modification_time > now() - INTERVAL 1 HOUR GROUP BY minute ORDER BY minute DESC`
6. **Risk assessment:** More than 300 parts per partition means TooManyParts imminent; above 200 is warning; below 100 is healthy.
