Post structured Grafana alert RCA summary to Slack.

## Prerequisites

- Structured RCA JSON from synthesize-rca (and optional cloud-triage escalation notes).
- `prior_incidents` reuse flag when applicable.

## Steps

1. Format Slack message with: investigation_id, summary, root_cause, confidence, top evidence links.
2. When `cce_summary` is present, include an **affected modules** markdown table (repo/module, provider, file:line call sites) so stakeholders see scoped blast radius — not whole-org noise.
3. Mention when a prior incident pattern was reused from `shared:incidents`.
4. Include recommended next steps and noise-hygiene hints when storm_context indicates correlated groups.
5. Post via Slack integration — do not dump raw webhook JSON.

## Guardrails

- Redact PII from Slack content.
- Link to Grafana dashboards and GitHub commits when evidence_links are present.
