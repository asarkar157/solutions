Normalize inbound FireHydrant and/or private Grafana payloads into `normalized_incident` JSON.

## Steps

1. Parse FireHydrant incident: id, name, priority, services, environments, timeline url.
2. Parse Grafana unified alerting: alert name, status, labels, annotations, generator URL.
3. Unify severity tokens (P1–P5 / SEV1–SEV5 / critical–info).
4. Set `sources` array and cross-links (`firehydrant_incident_id`, `grafana_fingerprint`).
5. Persist JSON for downstream stages only.

## Guardrails

- Read-only on source systems.
