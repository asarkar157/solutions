Normalize an inbound Datadog monitor alert webhook into a stable incident envelope for multi-tenant SaaS RCA.

## Steps

1. Parse the webhook JSON: alert id, monitor id, title, status, alert type, priority, tags, and monitor URL.
2. Extract tenant identifiers from Datadog tags using key `${tenant_tag_key}`; also capture `env`, `service`, `version`, and `host` when present.
3. Map Datadog priority/alert type to an internal severity label (P1–P5 / critical–info).
4. Build a `normalized_alert` object with: `alert_id`, `monitor_id`, `title`, `severity`, `service`, `environment`, `tenant_id`, `datadog_url`, `fired_at`, `tags`, `raw_summary`.
5. Attach Datadog metric and log query hints scoped to tenant tags.
6. Generate a stable `investigation_id` (UUID or alert_id-based slug) for downstream Slack collaboration.
7. Persist the normalized envelope as stage output JSON — downstream investigation stages consume this schema only.

## Guardrails

- Read-only on Datadog; do not mute monitors or create downtimes unless explicitly requested later.
- Redact customer PII from summaries before writing to shared notes.
- Reject or flag alerts missing tenant scope when multi-tenant isolation is required.
