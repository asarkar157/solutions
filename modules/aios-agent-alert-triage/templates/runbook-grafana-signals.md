Collect Grafana observability signals for a Grafana alert incident.

## Steps

1. Load `normalized_alert` JSON from the prior stage.
2. Anchor a ±15 minute window around `fired_at`.
3. Use scoped Grafana tools — list firing instances for the alert `rule_uid` when available; avoid fleet-wide alert scans.
4. Pull related alert history, dashboard links, and golden-signal panel hints for the incident window.
5. Apply Google SRE golden signals (latency, traffic, errors, saturation) when dashboards exist.
6. Emit `grafana_signals` JSON with metric excerpts, related firing alerts, dashboard links, and time window.

## Guardrails

- Read-only Grafana queries only.
- Scope to the alert's environment and namespace labels.
- Prefer `list_firing_instances` over broad instance listing.
