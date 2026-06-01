Capture a read-only Grafana health snapshot for PrivateSaaS connectivity audit.

## Steps

1. Query Grafana health endpoints, datasource connectivity, and alertmanager status.
2. List firing alerts, silences, and notification channel health.
3. Sample key dashboard panel availability for the configured environment.
4. Emit `grafana_health_snapshot` JSON with status, failing datasources, and active alert counts.

## Guardrails

- Read-only — no configuration changes.
