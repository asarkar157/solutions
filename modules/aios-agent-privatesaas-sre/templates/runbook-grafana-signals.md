Collect private Grafana observability signals for the incident window.

## Steps

1. Query alert history and related dashboards for `service` / `namespace` labels.
2. Pull Prometheus or datasource metrics for error rate, latency, and saturation.
3. Capture panel queries and dashboard UIDs when generator URLs are present.
4. Emit `grafana_signals` JSON with metric deltas and dashboard links (internal URLs).

## Guardrails

- Read-only; do not silence or edit alert rules.
