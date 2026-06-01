Normalize an inbound PagerDuty v3 webhook payload into a stable incident envelope for Azure SaaS triage.

## Steps

1. Parse the webhook JSON: incident id, title, urgency, priority, service name, custom details, and links.
2. Extract tenant identifiers from custom details or tags (`tenant_id`, `customer`, `environment`, `subscription_id`).
3. Map PagerDuty priority/urgency to an internal severity label (P1–P5 / SEV1–SEV5).
4. Build a `normalized_alert` object with: `incident_id`, `title`, `severity`, `service`, `environment`, `tenant_id`, `pagerduty_url`, `raw_summary`.
5. Add Datadog query hints when monitor links or tags are present (`host`, `service`, `env`, `version`).
6. Persist the normalized envelope as stage output JSON — downstream investigation stages consume this schema only.

## Guardrails

- Read-only on PagerDuty (fetch incident notes if needed); do not acknowledge or resolve unless explicitly requested later.
- Redact customer PII from summaries before writing to shared notes.
