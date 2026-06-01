Collect Grafana observability signals for a PrivateSaaS incident.

## Steps

1. Load `normalized_alert` JSON from the prior stage.
2. Anchor a ±15 minute window around `fired_at`.
3. Query Grafana dashboards and Prometheus datasources for the alert's environment/namespace/service labels.
4. Pull related alert history, panel snapshots, and metric time series for the incident window.
5. Emit `grafana_signals` JSON with metric excerpts, related firing alerts, and dashboard links.

## Guardrails

- Read-only Grafana queries only.
- Scope to the alert's environment and namespace labels.
