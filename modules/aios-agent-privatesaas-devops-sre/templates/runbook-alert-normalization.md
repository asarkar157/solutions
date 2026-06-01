Normalize an inbound private Grafana unified alerting webhook payload into a stable incident envelope for PrivateSaaS triage.

## Steps

1. Parse the webhook JSON: alert name, status, labels, annotations, generator URL, and dashboard UID.
2. Extract environment and namespace from labels (`environment`, `namespace`, `cluster`, `service`, `severity`).
3. Map Grafana severity labels to an internal severity label (P1–P5 / SEV1–SEV5 / critical/warning/info).
4. Build a `normalized_alert` object with: `alert_name`, `status`, `severity`, `environment`, `namespace`, `service`, `cluster`, `generator_url`, `labels`, `annotations`, `fired_at`.
5. Add Grafana dashboard/panel query hints when generator URLs or dashboard UIDs are present.
6. Persist the normalized envelope as stage output JSON — downstream investigation stages consume this schema only.

## Guardrails

- Read-only on Grafana; do not silence or modify alert rules during normalization.
- Redact internal credentials from summaries before writing to shared notes.
- Assume private VPC endpoints only — no public SaaS URLs.
