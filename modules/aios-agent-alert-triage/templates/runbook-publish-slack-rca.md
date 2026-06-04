Post structured Grafana alert RCA summary to Slack.

## Prerequisites

- Structured RCA JSON from synthesize-rca (and optional cloud-triage escalation notes).
- `prior_incidents` reuse flag when applicable.

## Steps

1. Format Slack message with: investigation_id, summary, root_cause, confidence, top evidence links.
2. Mention when a prior incident pattern was reused from `shared:incidents`.
3. Include recommended next steps and noise-hygiene hints when storm_context indicates correlated groups.
4. Post via Slack integration — do not dump raw webhook JSON.

## Guardrails

- Redact PII from Slack content.
- Link to Grafana dashboards and GitHub commits when evidence_links are present.
