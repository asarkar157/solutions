Investigate a ServiceNow ticket using Grafana (Prometheus datasources) and AWS observability.

## Prerequisites

- `enriched_ticket` JSON from the enrich-ticket stage.
- Grafana integration for dashboards, alert rules, and Prometheus queries.
- AWS integration for CloudWatch, resource health, and deployment signals.

## Steps

1. **Time window** — Anchor investigation ±15 minutes around the ticket opened or updated timestamp.
2. **Grafana sweep** — Pull related alert rules, dashboard panels, and Prometheus queries for service/env labels tied to the CI.
3. **AWS sweep** — Inspect CloudWatch metrics, recent deployments, autoscaling events, and resource health for linked AWS resources.
4. **Correlate** — Join observability signals with the enriched ticket; identify likely root cause category (deploy, dependency, capacity, config, external).
5. **Evidence bundle** — Emit `investigation_report` with ranked hypotheses, supporting metric/log excerpts, `severity_recommendation`, and `remediation_category`.

## Output schema

Return `investigation_report` with `hypotheses[]`, `evidence[]`, `severity_recommendation`, and `remediation_category`.
