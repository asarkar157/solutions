Normalize an inbound Grafana unified alerting webhook payload into a stable incident envelope for alert-triage RCA.

## Steps

1. Parse the webhook JSON: alert name, status, labels, annotations, generator URL, and dashboard UID.
2. Extract `rule_uid` from labels (`__alert_rule_uid__`, `alert_rule_uid`, or annotations).
3. Extract environment context from labels (`environment`, `env`, `namespace`, `cluster`, `service`, `severity`).
4. Map Grafana severity labels to an internal severity label (P1–P5 / SEV1–SEV5 / critical/warning/info).
5. Build a `normalized_alert` object with: `investigation_id`, `alert_name`, `rule_uid`, `status`, `severity`, `environment`, `namespace`, `service`, `cluster`, `generator_url`, `labels`, `annotations`, `fired_at`.
6. Add Grafana dashboard/panel query hints when generator URLs or dashboard UIDs are present.
7. Persist the normalized envelope as stage output JSON — downstream stages consume this schema only.

## Guardrails

- Read-only on Grafana; do not silence or modify alert rules during normalization.
- Redact internal credentials from summaries before writing to shared notes.
- Generate `investigation_id` as a stable slug from rule_uid + fired_at when UUID is unavailable.
