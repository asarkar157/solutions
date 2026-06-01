Auto-investigate an Azure SaaS incident using Datadog observability and Azure resource diagnostics.

## Prerequisites

- `normalized_alert` JSON from the normalize-alert stage.
- Datadog integration for metrics, logs, monitors, and APM traces.
- Azure integration for subscription/resource health, App Service, AKS, SQL, and Storage signals.

## Steps

1. **Time window** — Anchor investigation ±15 minutes around the alert fired-at timestamp.
2. **Datadog sweep** — Pull related monitors, error-rate dashboards, log patterns, and trace errors for the service/env tags.
3. **Azure sweep** — Inspect resource health, recent activity log events, failed deployments, and scaling metrics for the tenant-scoped resources.
4. **Correlate** — Join observability signals with the normalized alert; identify likely root cause category (deploy, dependency, capacity, config, external).
5. **Evidence bundle** — Emit structured findings: top hypotheses ranked by confidence, supporting metric/log excerpts, and recommended remediation category (`restart`, `scale`, `runbook`, `escalate`).

## Output schema

Return `investigation_report` with `hypotheses[]`, `evidence[]`, `severity_recommendation`, and `remediation_category`.
