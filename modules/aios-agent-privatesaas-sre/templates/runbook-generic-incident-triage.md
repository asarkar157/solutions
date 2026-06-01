Generic PrivateSaaS incident triage — normalize context before deep investigation.

Environment label: **${private_saas_environment_label}**

## Steps

1. Confirm `normalized_incident` contains: `incident_id`, `severity`, `service`, `environment`, `sources` (firehydrant, grafana).
2. Record FireHydrant incident URL and Grafana alert fingerprint when present.
3. List active responders and incident commander from FireHydrant (read-only).
4. Capture top Grafana alert labels and firing time window.
5. Hand off stable JSON to downstream Grafana/GCP stages.

## Guardrails

- Read-only on all integrations during triage.
- Private/internal URLs only.
